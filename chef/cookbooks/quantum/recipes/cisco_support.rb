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
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
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
    :keystone_password => keystone_service_password,
    :keystone_tenant => keystone_service_tenant,
    :switches => quantum[:quantum][:cisco_switches],
    :vlan_mode => vlan_mode
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

switches = {}
if vlan_mode
    switches = quantum[:quantum][:cisco_switches].to_hash
end

template "/etc/quantum/plugins/cisco/nexus.ini" do
  cookbook "quantum"
  source "cisco_nexus.ini.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :switches => switches,
    :vlan_mode => vlan_mode
  )
  notifies :restart, "service[#{node[:quantum][:platform][:service_name]}]"
end

ssh_keys = ""
switches.keys.each do |ip|
  ssh_keys << `ssh-keyscan #{ip} 2> /dev/null`
end

homedir = `getent passwd #{node[:quantum][:platform][:user]}`.split(':')[5]

directory "#{homedir}/.ssh" do
  mode 0700
  owner node[:quantum][:platform][:user]
  action :create
end

template "#{homedir}/.ssh/known_hosts" do
  source "ssh_known_hosts.erb"
  mode "0640"
  owner node[:quantum][:platform][:user]
  variables(
    :host_keys => ssh_keys
  )
end
