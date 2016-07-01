return unless node["roles"].include?("nagios-client")

svcs = []
ports = {}
node[:heat][:platform][:services].each { |svc| svcs << svc }
node[:heat][:api].each do |k, v|
    next if k !~ /port*/
    ports[k] = v
end

log ("Will monitor heat services: #{svcs.inspect}")

include_recipe "nagios::common"

template "/etc/nagios/nrpe.d/heat_nrpe.cfg" do
  source "heat_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables(
    heat_services: svcs,
    heat_ports: ports,
    heat_ip: node.ipaddress
  )
  notifies :restart, "service[nagios-nrpe-server]"
end
