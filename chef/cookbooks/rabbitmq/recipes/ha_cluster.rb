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

clustermon_op = { "monitor" => [{ "interval" => "10s" }] }
clustermon_params = { "extra_options" => "-E /usr/bin/rabbitmq-alert-handler.sh --watch-fencing" }
name = "rabbitmq-port-blocker"
clone_name = "cl-#{name}"
location_name = "l-#{name}-controller"
node_upgrading = CrowbarPacemakerHelper.being_upgraded?(node)
clone_running = "crm resource show #{clone_name}"
primitive_running = "crm resource show #{name}"
port = node[:rabbitmq][:port]
ssl_port = node[:rabbitmq][:ssl][:port]

crowbar_pacemaker_sync_mark "wait-rabbitmq_alert_resources"

if CrowbarPacemakerHelper.cluster_nodes(node).size > 2 && !node_upgrading
  template "/usr/bin/rabbitmq-alert-handler.sh" do
    source "rabbitmq-alert-handler.erb"
    owner "root"
    group "root"
    mode "0755"
    variables(node: node, nodes: CrowbarPacemakerHelper.cluster_nodes(node))
  end

  template "/usr/bin/#{name}.sh" do
    source "#{name}.erb"
    owner "root"
    group "root"
    mode "0755"
    variables(total_nodes: CrowbarPacemakerHelper.cluster_nodes(node).size,
              port: port, ssl_port: ssl_port)
  end

  pacemaker_primitive name do
    agent "ocf:pacemaker:ClusterMon"
    op clustermon_op
    params clustermon_params
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_clone clone_name do
    rsc name
    meta CrowbarPacemakerHelper.clone_meta(node)
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_location location_name do
    definition OpenStackHAHelper.controller_only_location(location_name, clone_name)
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_transaction name do
    cib_objects [
      "pacemaker_primitive[#{name}]",
      "pacemaker_clone[#{clone_name}]",
      "pacemaker_location[#{location_name}]"
    ]
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
else
  pacemaker_location location_name do
    definition OpenStackHAHelper.controller_only_location(location_name, clone_name)
    action :delete
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_clone "#{clone_name}_stop" do
    name clone_name
    rsc name
    meta CrowbarPacemakerHelper.clone_meta(node)
    action :stop
    only_if do
      running = system(clone_running, err: File::NULL)
      CrowbarPacemakerHelper.is_cluster_founder?(node) && running
    end
  end

  pacemaker_clone "#{clone_name}_delete" do
    name clone_name
    rsc name
    meta CrowbarPacemakerHelper.clone_meta(node)
    action :delete
    only_if do
      running = system(clone_running, err: File::NULL)
      CrowbarPacemakerHelper.is_cluster_founder?(node) && running
    end
  end

  pacemaker_primitive "#{name}_stop" do
    agent "ocf:pacemaker:ClusterMon"
    name name
    op clustermon_op
    params clustermon_params
    action :stop
    only_if do
      running = system(primitive_running, err: File::NULL)
      CrowbarPacemakerHelper.is_cluster_founder?(node) && running
    end
  end

  pacemaker_primitive "#{name}_delete" do
    agent "ocf:pacemaker:ClusterMon"
    name name
    op clustermon_op
    params clustermon_params
    action :delete
    only_if do
      running = system(primitive_running, err: File::NULL)
      CrowbarPacemakerHelper.is_cluster_founder?(node) && running
    end
  end

  file "/usr/bin/rabbitmq-alert-handler.sh" do
    action :delete
  end

  file "/usr/bin/#{name}.sh" do
    action :delete
  end

  # in case that the script was already deployed and the rule is already stored we need to clean it
  # up as to not left anything around
  bash "Remove existent rabbitmq blocking rules" do
    code "iptables -D INPUT -p tcp --destination-port 5672 "\
         "-m comment --comment \"rabbitmq port blocker (no quorum)\" -j DROP"
    only_if do
      # check for the rule
      cmd = "iptables -L -n | grep -F \"tcp dpt:5672 /* rabbitmq port blocker (no quorum) */\""
      system(cmd)
    end
  end
end

crowbar_pacemaker_sync_mark "create-rabbitmq_alert_resources"
