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

haproxy_loadbalancer "neutron-server" do
  address node[:neutron][:api][:service_host]
  port node[:neutron][:api][:service_port]
  use_ssl (node[:neutron][:api][:protocol] == "https")
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "neutron", "neutron-server", "server")
  action :nothing
end.run_action(:create)

# Wait for all "neutron-server" nodes to reach this point so we know that they
# will have all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-neutron_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-neutron_ha_resources"

primitives = []
transaction_objects = []

server_primitive_name = "neutron-server"
pacemaker_primitive server_primitive_name do
  agent node[:neutron][:ha][:server][:server_ra]
  op node[:neutron][:ha][:server][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_primitive[#{server_primitive_name}]"
primitives << server_primitive_name

if node[:neutron][:use_infoblox]
  infoblox_primitive_name = "infoblox-agent"
  pacemaker_primitive infoblox_primitive_name do
    agent node[:neutron][:ha][:infoblox][:infoblox_ra]
    op node[:neutron][:ha][:infoblox][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_primitive[#{infoblox_primitive_name}]"
  primitives << infoblox_primitive_name
end

group_name = "g-neutron"
pacemaker_group group_name do
  members primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{group_name}]"

clone_name = "cl-#{group_name}"
pacemaker_clone clone_name do
  rsc group_name
  meta CrowbarPacemakerHelper.clone_meta(node)
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{clone_name}]"

location_name = openstack_pacemaker_controller_only_location_for clone_name
transaction_objects << "pacemaker_location[#{location_name}]"

pacemaker_transaction "neutron server" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{clone_name}" do
  ordering ["postgresql", "rabbitmq", "cl-keystone", clone_name]
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-neutron_ha_resources"
