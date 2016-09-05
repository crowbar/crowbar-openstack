# Copyright 2017, SUSE Linux GmbH
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

unless node[:murano][:ha][:enabled]
  Chef::Log.info("HA disabled for Murano")
  return
end

include_recipe "crowbar-pacemaker::haproxy"

network_settings = MuranoHelper.network_settings(node)

haproxy_loadbalancer "murano-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl node[:murano][:api][:protocol] == "https"
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "murano",
                                                             "murano-server", "api_port")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-murano before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-murano_ha_resources"

transaction_objects = []
primitives = []

["api", "engine"].each do |service|
  primitive = "murano-#{service}"
  pacemaker_primitive primitive do
    agent node[:murano][:ha][service.to_sym][:ra]
    op node[:murano][:ha][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  primitives << primitive
  transaction_objects << "pacemaker_primitive[#{api_primitive}]"
end

group_name = "g-murano"
pacemaker_group group_name do
  members primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{group_name}]"

clone_name = "cl-#{group_name}"
pacemaker_clone clone_name do
  rsc group_name
  meta "clone-max" => CrowbarPacemakerHelper.num_corosync_nodes(node)
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{clone_name}]"

location_name = openstack_pacemaker_controller_only_location_for clone_name
transaction_objects << "pacemaker_location[#{location_name}]"

pacemaker_transaction "murano server" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-murano_ha_resources"
