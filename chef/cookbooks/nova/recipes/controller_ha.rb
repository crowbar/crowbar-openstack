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
  rate_limit node[:nova][:ha_rate_limit]["nova-api"]
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "nova-placement-api" do
  address "0.0.0.0"
  port node[:nova][:ports][:placement_api]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "placement_api")
  rate_limit node[:nova][:ha_rate_limit]["nova-placement-api"]
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "nova-metadata" do
  address cluster_admin_ip
  port node[:nova][:ports][:metadata]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "metadata")
  rate_limit node[:nova][:ha_rate_limit]["nova-metadata"]
  action :nothing
end.run_action(:create)

if node[:nova][:use_novnc]
  haproxy_loadbalancer "nova-novncproxy" do
    address "0.0.0.0"
    port node[:nova][:ports][:novncproxy]
    if node[:nova][:novnc][:ssl][:enabled]
      # novnc proxy does not like empty ssl packet followed by an RST
      # http://git.haproxy.org/?p=haproxy.git;a=commit;h=fd29cc537b8511db6e256529ded625c8e7f856d0
      # which is used for check-ssl
      # use_ssl #node[:nova][:novnc][:ssl][:enabled]
      mode "tcp"
      options ["tcpka", "tcplog"]
    end
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "novncproxy")
    rate_limit node[:nova][:ha_rate_limit]["nova-novncproxy"]
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
    rate_limit node[:nova][:ha_rate_limit]["nova-serialproxy"]
    action :nothing
  end.run_action(:create)
end
