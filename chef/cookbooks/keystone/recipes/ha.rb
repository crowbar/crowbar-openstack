# Copyright 2014 SUSE
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

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "keystone-service" do
  address node[:keystone][:api][:api_host]
  port node[:keystone][:api][:service_port]
  use_ssl (node[:keystone][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "keystone", "keystone-server", "service_port")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "keystone-admin" do
  address node[:keystone][:api][:admin_host]
  port node[:keystone][:api][:admin_port]
  use_ssl (node[:keystone][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "keystone", "keystone-server", "admin_port")
  action :nothing
end.run_action(:create)

if node[:keystone][:frontend] == "apache" && node[:pacemaker][:clone_stateless_services]
  include_recipe "crowbar-pacemaker::apache"

  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-keystone_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-keystone_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  transaction_objects = []

  # let's create a dummy resource for keystone, that can be used for ordering
  # constraints (as the apache2 resource is too vague)
  objects = openstack_pacemaker_controller_clone_for_transaction "keystone" do
    agent "ocf:pacemaker:Dummy"
    order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} )"
  end
  transaction_objects.push(objects)

  order_name = "o-cl-apache2-keystone"
  pacemaker_order order_name do
    ordering "cl-apache2 cl-keystone"
    score "Mandatory"
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_order[#{order_name}]"

  pacemaker_transaction "keystone server" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-keystone_ha_resources"
end

template "/usr/bin/keystone-fernet-keys-sync.sh" do
  source "keystone-fernet-keys-sync.sh"
  owner "root"
  group "root"
  mode "0755"
end

# handler scripts are run by hacluster user so sudo configuration is needed
# if the handler needs to rsync to other nodes using root's keys
template "/etc/sudoers.d/keystone-fernet-keys-sync" do
  source "hacluster_sudoers.erb"
  owner "root"
  group "root"
  mode "0440"
end

# on founder: create/delete pacemaker alert
pacemaker_alert "keystone-fernet-keys-sync" do
  handler "/usr/bin/keystone-fernet-keys-sync.sh"
  action node[:keystone][:signing][:token_format] == "fernet" ? :create : :delete
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
