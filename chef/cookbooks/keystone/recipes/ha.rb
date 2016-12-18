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

## Pacemaker is only used with native frontend
if node[:keystone][:frontend] == "native"
  # proposal_name = node[:keystone][:config][:environment]
  # monitor_creds = node[:keystone][:admin]

  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-keystone_before_ha"

  # Avoid races when creating pacemaker resources
  # (as a side-effect, if starting the service also does the db migration,
  # then we will avoid races there too as pacemaker will start the service).
  crowbar_pacemaker_sync_mark "wait-keystone_ha_resources"

  transaction_objects = []

  service_name = "keystone"
  pacemaker_primitive service_name do
    agent node[:keystone][:ha][:agent]
    # params ({
    #   "os_auth_url"    => node[:keystone][:api][:admin_auth_URL],
    #   "os_tenant_name" => monitor_creds[:tenant],
    #   "os_username"    => monitor_creds[:username],
    #   "os_password"    => monitor_creds[:password],
    #   "user"           => node[:keystone][:user]
    # })
    op node[:keystone][:ha][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_primitive[#{service_name}]"

  clone_name = "cl-#{service_name}"
  pacemaker_clone clone_name do
    rsc service_name
    meta ({ "clone-max" => CrowbarPacemakerHelper.num_corosync_nodes(node) })
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_clone[#{clone_name}]"

  location_name = openstack_pacemaker_controller_only_location_for clone_name
  transaction_objects << "pacemaker_location[#{location_name}]"

  pacemaker_transaction "keystone server" do
    cib_objects transaction_objects
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_order_only_existing "o-#{clone_name}" do
    ordering ["postgresql", "rabbitmq", clone_name]
    score "Optional"
    action :create
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-keystone_ha_resources"
end
