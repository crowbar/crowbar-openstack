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

case node["platform"]
when "centos", "redhat"
  mongo_conf = "/etc/mongod.conf"
  mongo_service = "mongod"
  package "mongo-10gen"
  package "mongo-10gen-server"
else
  mongo_conf = "/etc/mongodb.conf"
  mongo_service = "mongodb"
  package "mongodb" do
    action :install
  end
end

template mongo_conf do
  mode 0644
  source "mongodb.conf.erb"
  variables(:listen_addr => node.fqdn)
  notifies :restart, "service[#{mongo_service}]", :immediately
end

# wait for mongodb start (ceilometer services need it running)
ruby_block "wait for mongodb start" do
  block do
    require 'timeout'
    begin
      Timeout.timeout(60) do
        while ! ::Kernel.system("mongo #{node.fqdn} --quiet < /dev/null &> /dev/null")
          Chef::Log.debug("mongodb still not reachable")
          sleep(2)
        end
      end
    rescue Timeout::Error
      Chef::Log.warn("mongodb does not seem to be responding 1 minute after start")
    end
  end
end

service mongo_service do
  supports :status => true, :restart => true
  action [:enable, :start]
end

ha_enabled = node[:ceilometer][:ha][:server][:enabled]
node_is_controller = node[:ceilometer][:ha][:mongodb][:replica_set][:controller]
if ha_enabled && node_is_controller
  # install the package immediately because we need it to configure the
  # replicaset
  package("rubygem-mongo").run_action(:install)

  members = search(:node, "ceilometer_ha_mongodb_replica_set_member:true").sort
  CeilometerHelper.configure_replicaset(node, "crowbar-ceilometer", members)
end
