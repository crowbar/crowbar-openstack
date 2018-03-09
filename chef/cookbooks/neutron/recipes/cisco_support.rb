node[:neutron][:platform][:cisco_pkgs].each { |p| package p }

neutron = node

if neutron[:neutron][:ml2_type_drivers].include? "vlan"
  vlan_mode = true
else
  vlan_mode = false
end

switches = {}
if vlan_mode
  switches = neutron[:neutron][:cisco_switches].to_hash
end

# Empty the config file to avoid confusion (it may be a symlink, due to some
# old code we had)
old_config = "/etc/neutron/plugins/ml2/ml2_conf_cisco.ini"
link old_config do
  action :delete
  only_if "test -L #{old_config}"
end
file old_config do
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  content "# Please use config file snippets in /etc/neutron/neutron.conf.d/.\n" \
          "# See /etc/neutron/README.config for more details.\n"
end

# remove old snippet that was created previously
file "/etc/neutron/neutron-server.conf.d/100-ml2_conf_cisco.ini.conf" do
  action :delete
end

template node[:neutron][:ml2_cisco_config_file] do
  cookbook "neutron"
  source "ml2_conf_cisco.ini.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    switches: switches,
    vlan_mode: vlan_mode
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

ssh_keys = ""
switches.keys.each do |ip|
  ssh_keys << `ssh-keyscan #{ip} 2> /dev/null`
end

homedir = `getent passwd #{node[:neutron][:platform][:user]}`.split(":")[5]

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
    host_keys: ssh_keys
  )
end
