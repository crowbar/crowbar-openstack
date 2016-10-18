# Copyright 2016 SUSE, Inc.
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

haproxy_loadbalancer "aodh-api" do
  address "0.0.0.0"
  port node[:aodh][:api][:port]
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "aodh", "ceilometer-server", "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-aodh_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-aodh_ha_resources"

transaction_objects = []
primitives = []

node[:aodh][:platform][:services].each do |service|
  primitive_name = "aodh-#{service}"

  pacemaker_primitive primitive_name do
    agent node[:aodh][:ha][service.to_sym][:agent]
    op node[:aodh][:ha][service.to_sym][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  primitives << primitive_name
  transaction_objects << "pacemaker_primitive[#{primitive_name}]"
end

group_name = "g-aodh"
pacemaker_group group_name do
  members primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{group_name}]"

clone_name = "cl-#{group_name}"
pacemaker_clone clone_name do
  rsc group_name
  meta ({ "clone-max" => CrowbarPacemakerHelper.num_corosync_nodes(node) })
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{clone_name}]"
transaction_objects = CrowbarPacemakerHelper.add_upgraded_only_location(
  node, transaction_objects, clone_name
)

order_only_existing = ["rabbitmq", "cl-keystone", clone_name]

if node[:ceilometer][:use_mongodb]
  pacemaker_order "o-ceilometer-mongo" do
    score "Mandatory"
    ordering "cl-mongodb #{clone_name}"
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_order[o-ceilometer-mongo]"
else
  # we don't make the db mandatory if not mongodb; this is debatable, but
  # oslo.db is supposed to deal well with reconnections; it's less clear about
  # mongodb
  order_only_existing.unshift "postgresql"
end

location_name = openstack_pacemaker_controller_only_location_for clone_name
transaction_objects << "pacemaker_location[#{location_name}]"

pacemaker_transaction "aodh" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{clone_name}" do
  ordering order_only_existing
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-aodh_ha_resources"
