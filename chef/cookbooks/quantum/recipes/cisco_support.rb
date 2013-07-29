node[:quantum][:platform][:cisco_pkgs].each { |p| package p }

quantum = node

env_filter = " AND keystone_config_environment:keystone-config-#{node[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_host = keystone[:fqdn]
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_user = node["quantum"]["service_user"]
keystone_service_password = node["quantum"]["service_password"]
keystone_service_url = "#{keystone_protocol}://#{keystone_host}:#{keystone_admin_port}/v2.0"
Chef::Log.info("Keystone server found at #{keystone_host}")

if quantum[:quantum][:networking_mode] == 'vlan'
  vlan_mode = true
else
  vlan_mode = false
end

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
vlan_end = vlan_start + 2000

template "/etc/quantum/plugins/cisco/cisco_plugins.ini" do
  cookbook "quantum"
  source "cisco_plugins.ini.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :vlan_mode => vlan_mode
  )
  notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
end

template "/etc/quantum/plugins/cisco/credentials.ini" do
  cookbook "quantum"
  source "cisco_credentials.ini.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :keystone_url => keystone_service_url,
    :keystone_username => keystone_service_user,
    :keystone_password => keystone_service_password
  )
  notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
end

template "/etc/quantum/plugins/cisco/db_conn.ini" do
  cookbook "quantum"
  source "cisco_db_conn.ini.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :db_name => quantum[:quantum][:db][:cisco_database],
    :db_user => quantum[:quantum][:db][:cisco_user],
    :db_pass => quantum[:quantum][:db][:cisco_password],
    :db_host => quantum[:quantum][:db][:cisco_sql_address]
  )
  notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
end

template "/etc/quantum/plugins/cisco/l2network_plugin.ini" do
  cookbook "quantum"
  source "cisco_l2network_plugin.ini.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :vlan_start => vlan_start,
    :vlan_end => vlan_end
  )
  notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
end

computes = search(:node, "crowbar_cisco_switch_ip:* AND crowbar_cisco_switch_port:*") or []
switches = {}
computes.each do |compute|
  next if compute[:crowbar].nil?
  next if compute[:crowbar][:cisco_switch].nil?
  next if compute[:crowbar][:cisco_switch][:ip].nil?
  next if compute[:crowbar][:cisco_switch][:port].nil?
  ip = compute[:crowbar][:cisco_switch][:ip]
  port = compute[:crowbar][:cisco_switch][:port]
  if ip.length and port.length
    switches[ip] = {} if switches[ip].nil?
    switches[ip][port] = {} if switches[ip][port].nil?
    switches[ip][port][:host] = compute[:hostname]
  end
end
template "/etc/quantum/plugins/cisco/nexus.ini" do
  cookbook "quantum"
  source "cisco_nexus.ini.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :switches => switches
  )
  notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
end
