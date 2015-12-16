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

haproxy_loadbalancer "ceilometer-api" do
  address "0.0.0.0"
  port node[:ceilometer][:api][:port]
  use_ssl false
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "ceilometer", "ceilometer-server", "api")
  action :nothing
end.run_action(:create)

# Wait for all nodes to reach this point so we know that they will have
# all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-ceilometer_server_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-ceilometer_server_ha_resources"

primitives = []

["collector", "agent_notification", "api", "alarm_evaluator", "alarm_notifier"].each do |service|
  primitive_name = "ceilometer-#{service}"

  pacemaker_primitive primitive_name do
    agent node[:ceilometer][:ha][service.to_sym][:agent]
    op node[:ceilometer][:ha][service.to_sym][:op]
    action :create
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  primitives << primitive_name
end

group_name = "g-ceilometer-server"

pacemaker_group group_name do
  members primitives
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

pacemaker_clone "cl-#{group_name}" do
  rsc group_name
  action [:create, :start]
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

order_only_existing = ["rabbitmq", "cl-keystone", "cl-#{group_name}"]

if node[:ceilometer][:use_mongodb]
  pacemaker_order "o-ceilometer-mongo" do
    score "Mandatory"
    ordering "cl-mongodb cl-#{group_name}"
    action :create
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
else
  # we don't make the db mandatory if not mongodb; this is debatable, but
  # oslo.db is supposed to deal well with reconnections; it's less clear about
  # mongodb
  order_only_existing.unshift "postgresql"
end

crowbar_pacemaker_order_only_existing "o-cl-#{group_name}" do
  ordering order_only_existing
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-ceilometer_server_ha_resources"
