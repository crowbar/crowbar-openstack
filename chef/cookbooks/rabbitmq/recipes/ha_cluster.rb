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

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-rabbitmq_before_ha"

crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_resources"

transaction_objects = []

service_name = "rabbitmq"
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

ms_name = "ms-#{service_name}"
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
end

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_resources"

# wait for service to have a master, and to be active
ruby_block "wait for #{ms_name} to be started" do
  block do
    require "timeout"
    begin
      Timeout.timeout(240) do
        # Check that the service is running
        cmd = "crm resource show #{ms_name} 2> /dev/null "
        cmd << "| grep -q \"is running on\""
        until ::Kernel.system(cmd)
          Chef::Log.debug("#{ms_name} still not started")
          sleep(2)
        end
        # The sed command grabs everything between '{running_applications'
        # and ']}', and what we want is that the rabbit application is
        # running
        cmd = "rabbitmqctl -q status 2> /dev/null "
        cmd << "| sed -n '/{running_applications/,/\]}/p' | grep -q '{rabbit,'"
        until ::Kernel.system(cmd)
          Chef::Log.debug("#{ms_name} still not answering")
          sleep(2)
        end
      end
    rescue Timeout::Error
      message = "The #{ms_name} pacemaker resource is not started. Please manually check for an error."
      Chef::Log.fatal(message)
      raise message
    end
  end # block
end # ruby_block
