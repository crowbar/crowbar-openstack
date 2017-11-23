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

unless node[:barbican][:ha][:enabled]
  log "HA support for barbican is not enabled"
  return
end

log "Setting up barbican HA support"

network_settings = BarbicanHelper.network_settings(node)

ssl_enabled = node[:barbican][:api][:ssl]

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "barbican-api" do
  address network_settings[:api][:ha_bind_host]
  port network_settings[:api][:ha_bind_port]
  use_ssl ssl_enabled
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "barbican", "barbican-controller", "api"
  )
  action :nothing
end.run_action(:create)

if node[:pacemaker][:clone_stateless_services]
  # Wait for all nodes to reach this point so we know that all nodes will have
  # all the required packages installed before we create the pacemaker
  # resources
  crowbar_pacemaker_sync_mark "sync-barbican_before_ha"

  # Avoid races when creating pacemaker resources
  crowbar_pacemaker_sync_mark "wait-barbican_ha_resources"

  rabbit_settings = fetch_rabbitmq_settings
  transaction_objects = []

  services =
    if node[:barbican][:enable_keystone_listener]
      ["worker", "keystone-listener"]
    else
      ["worker"]
    end

  services.each do |service|
    primitive_name = "barbican-#{service}"

    objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
      agent node[:barbican][:ha][service.to_sym][:agent]
      op node[:barbican][:ha][service.to_sym][:op]
      order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"
    end
    transaction_objects.push(objects)
  end

  pacemaker_transaction "barbican server" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-barbican_ha_resources"

  include_recipe "crowbar-pacemaker::apache"
end
