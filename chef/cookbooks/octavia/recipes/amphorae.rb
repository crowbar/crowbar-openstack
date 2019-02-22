package "openstack-octavia-amphora-agent"

list = search(:node, "roles:octavia-health-manager") || []

hm_port = node[:octavia]["health-manager"][:port]
node_list = []
list.each do |e|
  str = e.name + ":" + hm_port.to_s
  node_list << str unless node_list.include?(str)
end

template "/etc/octavia/amphora-agent.conf" do
  source "amphora-agent.conf.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
  variables(
    octavia_healthmanager_bind_host: "0.0.0.0", #HACK: It has to be configured from UI
    octavia_healthmanager_hosts: node_list.join(",")
  )
end

file node[:octavia][:octavia_log_dir] + "/amphora-agent.log" do
  action :touch
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
end

service "openstack-octavia-amphora-agent" do
  service_name "openstack-octavia-amphora-agent"
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: "/etc/octavia/amphora-agent.conf")
 # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
