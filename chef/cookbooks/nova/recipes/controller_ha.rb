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

unless node[:nova][:ha][:enabled]
  log "HA support for nova is disabled"
  return
end

log "HA support for nova is enabled"

cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "nova-api" do
  address "0.0.0.0"
  port node[:nova][:ports][:api]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "api")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "nova-metadata" do
  address cluster_admin_ip
  port node[:nova][:ports][:metadata]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "metadata")
  action :nothing
end.run_action(:create)

if node[:nova][:use_novnc]
  haproxy_loadbalancer "nova-novncproxy" do
    address "0.0.0.0"
    port node[:nova][:ports][:novncproxy]
    use_ssl node[:nova][:novnc][:ssl][:enabled]
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "novncproxy")
    action :nothing
  end.run_action(:create)
end
if node[:nova][:use_serial]
  haproxy_loadbalancer "nova-serialproxy" do
    address "0.0.0.0"
    port node[:nova][:ports][:serialproxy]
    use_ssl node[:nova][:serial][:ssl][:enabled]
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node,
      "nova",
      "nova-controller",
      "serialproxy")
    action :nothing
  end.run_action(:create)
end
# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-nova_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-nova_ha_resources"

rabbit_settings = fetch_rabbitmq_settings
transaction_objects = []

services = %w(api cert conductor consoleauth scheduler)
if node[:nova][:use_novnc]
  services << "novncproxy"
end
if node[:nova][:use_serial]
  services << "serialproxy"
end

services.each do |service|
  if %w(rhel suse).include?(node[:platform_family])
    primitive_ra = "systemd:openstack-nova-#{service}"
  else
    primitive_ra = "systemd:nova-#{service}"
  end

  primitive_name = "nova-#{service}"

  objects = openstack_pacemaker_controller_clone_for_transaction primitive_name do
    agent primitive_ra
    op node[:nova][:ha][:op]
    order_only_existing "( postgresql #{rabbit_settings[:pacemaker_resource]} cl-keystone )"
  end
  transaction_objects.push(objects)
end

pacemaker_transaction "nova controller" do
  cib_objects transaction_objects.flatten
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-nova_ha_resources"
