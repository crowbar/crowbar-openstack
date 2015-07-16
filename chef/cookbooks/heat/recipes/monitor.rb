svcs = []
ports = {}
node.default[:heat][:platform][:services].each {|svc| svcs << svc}
node.default[:heat][:api].each do |k,v|
    next if k !~ /port*/
    ports[k] = v
end

log ("Will monitor heat services: #{svcs.inspect}")

include_recipe "nagios::common" if node["roles"].include?("nagios-client")

template "/etc/nagios/nrpe.d/heat_nrpe.cfg" do
  source "heat_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables( {
    :heat_services => svcs,
    :heat_ports => ports,
    :heat_ip => node.ipaddress
  })
   notifies :restart, "service[nagios-nrpe-server]"
end if node["roles"].include?("nagios-client")
