unless node[:octavia][:ha][:enabled]
  log "HA support for octavia is disabled"
  return
end

log "HA support for octavia is enabled"

network_settings = OctaviaHelper.network_settings(node)

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "octavia-api" do
  address network_settings[:api][:bind_host]
  port node[:octavia][:api][:port]
  use_ssl node[:octavia][:api][:protocol] == "https"
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "octavia", "octavia-api", "api")
  rate_limit node[:octavia][:ha_rate_limit]["octavia-api"]
  action :nothing
end.run_action(:create)
