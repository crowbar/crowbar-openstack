node[:neutron][:platform][:cisco_pkgs].each { |p| package p }

neutron = node

env_filter = " AND keystone_config_environment:keystone-config-#{node[:neutron][:keystone_instance]}"
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
keystone_service_user = node["neutron"]["service_user"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_password = node["neutron"]["service_password"]
keystone_service_url = "#{keystone_protocol}://#{keystone_host}:#{keystone_admin_port}/v2.0"
Chef::Log.info("Keystone server found at #{keystone_host}")

if neutron[:neutron][:networking_mode] == 'vlan'
  vlan_mode = true
else
  vlan_mode = false
end

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
vlan_end = vlan_start + 2000

template "/etc/neutron/plugins/cisco/cisco_plugins.ini" do
  cookbook "neutron"
  source "cisco_plugins.ini.erb"
  mode "0640"
  owner node[:neutron][:platform][:user]
  variables(
    :vlan_mode => vlan_mode
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

template "/etc/neutron/plugins/cisco/credentials.ini" do
  cookbook "neutron"
  source "cisco_credentials.ini.erb"
  mode "0640"
  owner node[:neutron][:platform][:user]
  variables(
    :keystone_url => keystone_service_url,
    :keystone_username => keystone_service_user,
    :keystone_password => keystone_service_password,
    :keystone_tenant => keystone_service_tenant,
    :switches => neutron[:neutron][:cisco_switches],
    :vlan_mode => vlan_mode
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

template "/etc/neutron/plugins/cisco/db_conn.ini" do
  cookbook "neutron"
  source "cisco_db_conn.ini.erb"
  mode "0640"
  owner node[:neutron][:platform][:user]
  variables(
    :db_name => neutron[:neutron][:db][:cisco_database],
    :db_user => neutron[:neutron][:db][:cisco_user],
    :db_pass => neutron[:neutron][:db][:cisco_password],
    :db_host => neutron[:neutron][:db][:cisco_sql_address]
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

template "/etc/neutron/plugins/cisco/l2network_plugin.ini" do
  cookbook "neutron"
  source "cisco_l2network_plugin.ini.erb"
  mode "0640"
  owner node[:neutron][:platform][:user]
  variables(
    :vlan_start => vlan_start,
    :vlan_end => vlan_end
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

switches = {}
if vlan_mode
    switches = neutron[:neutron][:cisco_switches].to_hash
end

template "/etc/neutron/plugins/cisco/nexus.ini" do
  cookbook "neutron"
  source "cisco_nexus.ini.erb"
  mode "0640"
  owner node[:neutron][:platform][:user]
  variables(
    :switches => switches,
    :vlan_mode => vlan_mode
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

ssh_keys = ""
switches.keys.each do |ip|
  ssh_keys << `ssh-keyscan #{ip} 2> /dev/null`
end

homedir = `getent passwd #{node[:neutron][:platform][:user]}`.split(':')[5]

directory "#{homedir}/.ssh" do
  mode 0700
  owner node[:neutron][:platform][:user]
  action :create
end

template "#{homedir}/.ssh/known_hosts" do
  source "ssh_known_hosts.erb"
  mode "0640"
  owner node[:neutron][:platform][:user]
  variables(
    :host_keys => ssh_keys
  )
end
