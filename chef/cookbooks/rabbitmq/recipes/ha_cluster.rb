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

agent_name = "systemd:rabbitmq-server"
founder = CrowbarPacemakerHelper.cluster_founder(node)

# set the shared rabbitmq cookie
# cookie is automatically set during barclamp apply
# on the apply_role_pre_chef_call method
file node[:rabbitmq][:erlang_cookie_path] do
  content node[:rabbitmq][:erlang_cookie]
  owner node[:rabbitmq][:rabbitmq_user]
  group node[:rabbitmq][:rabbitmq_group]
  mode 0o400
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-rabbitmq_before_ha"

crowbar_pacemaker_sync_mark "wait-rabbitmq_ha_resources"

transaction_objects = openstack_pacemaker_controller_clone_for_transaction "rabbitmq-server" do
  agent agent_name
  op node[:rabbitmq][:ha][:clustered_op]
end

pacemaker_transaction "rabbitmq service" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-rabbitmq_ha_resources"

unless node[:rabbitmq][:bootstrapped]
  execute "rabbitmqctl stop_app" do
    action :run
    only_if { system("rabbitmqctl status|grep -q RabbitMQ") }
    not_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  execute "rabbitmqctl join_cluster rabbit@#{founder[:hostname]}" do
    action :run
    not_if do
      CrowbarPacemakerHelper.is_cluster_founder?(node) \
      && system("rabbitmqctl status|grep -q RabbitMQ")
    end
  end

  execute "rabbitmqctl start_app" do
    action :run
    not_if do
      CrowbarPacemakerHelper.is_cluster_founder?(node) \
      && system("rabbitmqctl status|grep -q RabbitMQ")
    end
  end

  ruby_block "mark as bootstrapped" do
    block do
      node[:rabbitmq][:bootstrapped] = true
      node.save
    end
  end
end
