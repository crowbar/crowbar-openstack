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
rabbitmq_op = {}
rabbitmq_op["monitor"] = {}
rabbitmq_op["monitor"]["interval"] = "10s"

crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_resources"

transaction_objects = []

service_name = "rabbitmq"
pacemaker_primitive service_name do
  agent agent_name
  # nodename is empty so that we explicitly depend on the config files
  params ({
    "erlang_cookie" => node[:rabbitmq][:erlang_cookie],
    "pid_file" => pid_file,
    "rmq_feature_health_check" => false,
    "rmq_feature_local_list_queues" => false,
    "default_vhost" => node[:rabbitmq][:vhost]
  })
  op rabbitmq_op
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
      # 30s (our usual timeout) is a bit short with this OCF RA which
      # stops/starts the rabbit app multiple times due to the master-slave
      # config
      Timeout.timeout(60) do
        ::Kernel.system("crm_resource --wait --resource #{ms_name}")
        ::Kernel.system("rabbitmqctl wait #{pid_file}")
      end
    rescue Timeout::Error
      message = "RabbitMQ is not started. Please manually check for an error."
      Chef::Log.fatal(message)
      raise message
    end
  end # block
end # ruby_block
