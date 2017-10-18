# Copyright 2014 SUSE Linux, GmbH
# Copyright 2011 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case node[:platform_family]
when "rhel"
  mongo_conf = "/etc/mongod.conf"
  mongo_service = "mongod"
  package "mongo-10gen"
  package "mongo-10gen-server"
else
  mongo_conf = "/etc/mongodb.conf"
  mongo_service = "mongodb"
  package "mongodb"
end

template mongo_conf do
  mode 0644
  source "mongodb.conf.erb"
  variables(
    listen_addr: Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    )
  notifies :restart, "service[#{mongo_service}]", :immediately
end

ha_enabled = node[:ceilometer][:ha][:server][:enabled]

service mongo_service do
  supports status: true, restart: true
  action [:enable, :start]
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
utils_systemd_service_restart mongo_service do
  action ha_enabled ? :disable : :enable
end

if ha_enabled
  # Wait for all nodes to reach this point so we know that all nodes
  # will have all the required packages installed and configured before
  # we create the pacemaker resources.
  crowbar_pacemaker_sync_mark "sync-mongodb_before_ha"

  crowbar_pacemaker_sync_mark "wait-mongodb_service"

  transaction_objects = []

  objects = openstack_pacemaker_controller_clone_for_transaction service_name do
    agent node[:ceilometer][:ha][:mongodb][:agent]
    op node[:ceilometer][:ha][:mongodb][:op]
  end
  transaction_objects.push(objects)

  pacemaker_transaction "mongodb" do
    cib_objects transaction_objects.flatten
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-mongodb_service"

  if node[:ceilometer][:ha][:mongodb][:replica_set][:controller]
    # install the package immediately because we need it to configure the
    # replicaset
    package("ruby#{node["languages"]["ruby"]["version"].to_f}-rubygem-mongo").run_action(:install)

    members = CeilometerHelper.replica_set_members(node)

    # configure replica set in a ruby block where we also wait for mongodb
    # because we need mongodb to be started (which is not the case in compile
    # phase)
    ruby_block "Configure MongoDB replica set" do
      block do
        require "timeout"
        begin
          mongodb_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

          Timeout.timeout(120) do
            while ! ::Kernel.system("mongo #{mongodb_address} --quiet < /dev/null &> /dev/null")
              Chef::Log.debug("mongodb still not reachable")
              sleep(2)
            end

            CeilometerHelper.configure_replicaset(node, "crowbar-ceilometer", members)
          end
        rescue Timeout::Error
          Chef::Log.warn("Cannot configure replicaset: mongodb does not seem to be responding after trying for 1 minute")
        end
      end
    end
  end
end
