node[:neutron][:platform][:cisco_pkgs].each { |p| package p }

neutron = node

if neutron[:neutron][:networking_mode] == 'vlan'
  vlan_mode = true
else
  vlan_mode = false
end

switches = {}
if vlan_mode
  switches = neutron[:neutron][:cisco_switches].to_hash
end

if node[:neutron][:use_ml2]
  
  template "/etc/neutron/plugins/ml2/ml2_conf_cisco.ini" do
    cookbook "neutron"
    source "ml2_conf_cisco.ini.erb"
    mode "0640"
    owner node[:neutron][:platform][:user]
    variables(
      :switches => switches,
      :vlan_mode => vlan_mode
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
else
  directory "/etc/neutron/plugins/cisco/" do
     mode 00775
     owner node[:neutron][:platform][:user]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end

  template "/etc/neutron/plugins/cisco/cisco_plugins.ini" do
    cookbook "neutron"
    source "cisco_plugins.ini.erb"
    mode "0640"
    owner node[:neutron][:platform][:user]
    variables(
      :switches => switches,
      :vlan_mode => vlan_mode
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
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
