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

include_recipe "crowbar-pacemaker::haproxy"

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

rabbit_settings = fetch_rabbitmq_settings
services = ["conductor", "api"]
transaction_objects = []

services.each do |service|
  primitive_name = "magnum-#{service}"
  ordering = "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone cl-heat-api )"

  objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
    agent node[:magnum][:ha][service.to_sym][:agent]
    op node[:magnum][:ha][service.to_sym][:op]
    order_only_existing ordering
  end
  transaction_objects.push(objects)
end

pacemaker_transaction "magnum server" do
  cib_objects transaction_objects.flatten
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-magnum_ha_resources"
