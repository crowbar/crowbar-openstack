# Copyright 2016 SUSE Linux GmbH
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

unless node[:magnum][:ha][:enabled]
  log "HA support for magnum is not enabled"
  return
end

log "Setting up magnum HA support"

network_settings = MagnumHelper.network_settings(node)

ssl_enabled = (node[:magnum][:api][:protocol] == "https")

haproxy_loadbalancer "magnum-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl ssl_enabled
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "magnum", "magnum-server", "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-magnum_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-magnum_ha_resources"

primitives = []
transaction_objects = []

["conductor", "api"].each do |service|
  primitive_name = "magnum-#{service}"

  pacemaker_primitive primitive_name do
    agent node[:magnum][:ha][service.to_sym][:agent]
    op node[:magnum][:ha][service.to_sym][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  primitives << primitive_name
  transaction_objects << "pacemaker_primitive[#{primitive_name}]"
end

group_name = "g-magnum"

pacemaker_group group_name do
  members primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{group_name}]"

clone_name = "cl-#{group_name}"
pacemaker_clone clone_name do
  rsc group_name
  meta("clone-max" => CrowbarPacemakerHelper.num_corosync_nodes(node))
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{clone_name}]"

location_name = openstack_pacemaker_controller_only_location_for clone_name
transaction_objects << "pacemaker_location[#{location_name}]"
transaction_objects = CrowbarPacemakerHelper.add_upgraded_only_location(
  node, transaction_objects, clone_name
)

pacemaker_transaction "magnum server" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{clone_name}" do
  ordering ["postgresql", "rabbitmq", "cl-keystone", "cl-heat", clone_name]
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-magnum_ha_resources"
