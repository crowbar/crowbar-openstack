# Copyright 2017 SUSE
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

pid_file = "/var/run/rabbitmq/pid"

agent_name = "ocf:rabbitmq:rabbitmq-server-ha"

service_name = "rabbitmq"
ms_name = "ms-#{service_name}"

# create file that will be sourced by OCF resource agent on promote
template "/etc/rabbitmq/ocf-promote" do
  source "ocf-promote.erb"
  owner "root"
  group "root"
  mode 0o644
  variables(
    clustername: node[:rabbitmq][:clustername]
  )
end

# wait for service to have a master, and to be active
ruby_block "wait for #{ms_name} to be started" do
  block do
    require "timeout"
    begin
      Timeout.timeout(360) do
        # Do not check if rabbitmq is running when it is not supposed to run.
        # pre-upgrade attribute is set to true to indicate the case that the upgrade of the node has
        # not been finished yet. In such case, services cannot start on the node
        # (there's a location constraint that prevents that).
        # See disable_pre_upgrade_attribute_for method in models/api/node.rb for more info
        cmd = "crm_attribute --node #{node[:hostname]} --name pre-upgrade --query --quiet"
        cmd << "| grep -q true"
        break if ::Kernel.system(cmd)

        # Check that the service has a master
        cmd = "crm resource show #{ms_name} 2> /dev/null "
        cmd << "| grep \"is running on\" | grep -q \"Master\""
        until ::Kernel.system(cmd)
          Chef::Log.info("#{ms_name} still without master")
          sleep(2)
        end

        # Check that the service is running on this node
        cmd = "crm resource show #{ms_name} 2> /dev/null "
        cmd << "| grep -q \"is running on: #{node.hostname}\""
        until ::Kernel.system(cmd)
          Chef::Log.info("#{ms_name} still not running locally")
          sleep(2)
        end

        # The sed command grabs everything between '{running_applications'
        # and ']}', and what we want is that the rabbit application is
        # running
        # Checks if the actual rabbit app is running properly at least 5 times in a row
        # as to prevent continuing when its not stable enough
        cmd = "rabbitmqctl -q status 2> /dev/null "
        cmd << "| sed -n '/{running_applications/,/\]}/p' | grep -q '{rabbit,'"
        count = 0
        until count == 5
          if ::Kernel.system(cmd)
            count += 1
            sleep(2)
          else
            count = 0
          end
        end

        # Check that we dont have any pending pacemaker resource operations
        cmd = "crm resource operations #{ms_name} 2> /dev/null "
        cmd << "| grep -q \"pending\""
        while ::Kernel.system(cmd)
          Chef::Log.info("resource #{ms_name} still has pending operations")
          sleep(2)
        end
      end
    rescue Timeout::Error
      message = "The #{ms_name} pacemaker resource is not started or doesn't have a master yet."
      message << " Please manually check for an error."
      Chef::Log.fatal(message)
      raise message
    end
  end
  action :nothing
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-rabbitmq_before_ha"

crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_resources" do
  timeout 300
end

transaction_objects = []

pacemaker_primitive service_name do
  agent agent_name
  # nodename is empty so that we explicitly depend on the config files
  params ({
    "erlang_cookie" => node[:rabbitmq][:erlang_cookie],
    "pid_file" => pid_file,
    "policy_file" => "/etc/rabbitmq/ocf-promote",
    "rmq_feature_health_check" => node[:rabbitmq][:ha][:clustered_rmq_features],
    "rmq_feature_local_list_queues" => node[:rabbitmq][:ha][:clustered_rmq_features],
    "default_vhost" => node[:rabbitmq][:vhost]
  })
  op node[:rabbitmq][:ha][:clustered_op]
  meta ({
    "migration-threshold" => "10",
    "failure-timeout" => "30s",
    "resource-stickiness" => "100"
  })
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects.push("pacemaker_primitive[#{service_name}]")

# no location on the role here: the ms resource will have this constraint

pacemaker_ms ms_name do
  rsc service_name
  meta ({
    "master-max" => "1",
    "clone-max" => CrowbarPacemakerHelper.cluster_nodes(node).size,
    "master-node-max" => "1",
    "ordered" => "false",
    "interleave" => "false",
    "notify" => "true"
  })
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects.push("pacemaker_ms[#{ms_name}]")

ms_location_name = openstack_pacemaker_controller_only_location_for ms_name
transaction_objects.push("pacemaker_location[#{ms_location_name}]")

pacemaker_transaction "rabbitmq service" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  notifies :create, resources(ruby_block: "wait for #{ms_name} to be started"), :immediately
end

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_resources"
