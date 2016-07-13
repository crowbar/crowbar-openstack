# frozen_string_literal: true
return unless node["roles"].include?("nagios-client")

svcs = []
ports = {}
node[:ironic][:platform][:services].each { |svc| svcs << svc }
node[:ironic][:api].each do |k, v|
  next if k !~ /port*/
  ports[k] = v
end

log "Will monitor ironic services: #{svcs.inspect}"

include_recipe "nagios::common"

template "/etc/nagios/nrpe.d/ironic_nrpe.cfg" do
  source "ironic_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables(
    ironic_services: svcs,
    ironic_ports: ports,
    ironic_ip: node.ipaddress
  )
  notifies :restart, "service[nagios-nrpe-server]"
end
