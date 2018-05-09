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

        # Do not check if rabbitmq is running when it is not supposed to run.
        # pre-upgrade attribute is set to true to indicate the case that the upgrade of the node has
        # not been finished yet. In such case, services cannot start on the node
        # (there's a location constraint that prevents that).
        # See disable_pre_upgrade_attribute_for method in models/api/node.rb for more info
        cmd = "crm_attribute --node #{node[:hostname]} --name pre-upgrade --query --quiet"
        cmd << "| grep -q true"
        break if ::Kernel.system(cmd)

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

if CrowbarPacemakerHelper.cluster_nodes(node).size > 2 && !CrowbarPacemakerHelper.being_upgraded?(node)
  # create the directory to lock rabbitmq-port-blocker
  cookbook_file "/etc/tmpfiles.d/rabbitmq.conf" do
    owner "root"
    group "root"
    mode "0644"
    action :create
    source "rabbitmq.tmpfiles"
  end

  bash "create tmpfiles.d files for rabbitmq" do
    code "systemd-tmpfiles --create /etc/tmpfiles.d/rabbitmq.conf"
    action :nothing
    subscribes :run, resources("cookbook_file[/etc/tmpfiles.d/rabbitmq.conf]"), :immediately
  end

  # create the scripts to block the client port on startup
  template "/usr/bin/rabbitmq-alert-handler.sh" do
    source "rabbitmq-alert-handler.erb"
    owner "root"
    group "root"
    mode "0755"
    variables(node: node, nodes: CrowbarPacemakerHelper.cluster_nodes(node))
  end

  template "/usr/bin/rabbitmq-port-blocker.sh" do
    source "rabbitmq-port-blocker.erb"
    owner "root"
    group "root"
    mode "0755"
    variables(total_nodes: CrowbarPacemakerHelper.cluster_nodes(node).size)
  end

  template "/etc/sudoers.d/rabbitmq-port-blocker" do
    source "hacluster_sudoers.erb"
    owner "root"
    group "root"
    mode "0440"
  end

  # create the alert
  pacemaker_alert "rabbitmq-alert-handler" do
    handler "/usr/bin/rabbitmq-alert-handler.sh"
    action :create
  end
else
  pacemaker_alert "rabbitmq-alert-handler" do
    handler "/usr/bin/rabbitmq-alert-handler.sh"
    action :delete
  end

  cookbook_file "/etc/tmpfiles.d/rabbitmq.conf" do
    action :delete
  end

  file "/usr/bin/rabbitmq-alert-handler.sh" do
    action :delete
  end

  file "/usr/bin/rabbitmq-port-blocker.sh" do
    action :delete
  end

  file "/etc/sudoers.d/rabbitmq-port-blocker" do
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
