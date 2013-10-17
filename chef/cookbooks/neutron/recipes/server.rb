# Copyright 2011 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

unless node[:neutron][:use_gitrepo]
  case node[:neutron][:networking_plugin]
  when "openvswitch", "cisco"
    plugin_cfg_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
    neutron_agent = node[:neutron][:platform][:ovs_agent_name]
  when "linuxbridge"
    plugin_cfg_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
    neutron_agent = node[:neutron][:platform][:lb_agent_name]
  end
  pkgs = node[:neutron][:platform][:pkgs]
  pkgs.each { |p| package p }
  file "/etc/default/neutron-server" do
    action :delete
    not_if { node[:platform] == "suse" }
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
  template "/etc/sysconfig/neutron" do
    source "suse.sysconfig.neutron.erb"
    owner "root"
    group "root"
    mode 0640
    variables(
      :plugin_config_file => plugin_cfg_path
    )
    only_if { node[:platform] == "suse" }
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
else
  case node[:neutron][:networking_plugin]
  when "openvswitch"
    plugin_cfg_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
    neutron_agent = "neutron-openvswitch-agent"
  when "linuxbridge"
    plugin_cfg_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
    neutron_agent = "neutron-linuxbridge-agent"
  end
  neutron_service_name="neutron-server"
  neutron_path = "/opt/neutron"
  venv_path = node[:neutron][:use_virtualenv] ? "#{neutron_path}/.venv" : nil

  link_service "neutron-server" do
    virtualenv venv_path
    bin_name "neutron-server --config-dir /etc/neutron/"
  end
  link_service "neutron-dhcp-agent" do
    virtualenv venv_path
    bin_name "neutron-dhcp-agent --config-dir /etc/neutron/"
  end
  link_service "neutron-l3-agent" do
    virtualenv venv_path
    bin_name "neutron-l3-agent --config-dir /etc/neutron/"
  end
  link_service "neutron-metadata-agent" do
    virtualenv venv_path
    bin_name "neutron-metadata-agent --config-dir /etc/neutron/ --config-file /etc/neutron/metadata_agent.ini"
  end
end

include_recipe "neutron::database"
include_recipe "neutron::api_register"
include_recipe "neutron::common_install"

# Kill all the libvirt default networks.
execute "Destroy the libvirt default network" do
  command "virsh net-destroy default"
  only_if "virsh net-list |grep default"
end

link "/etc/libvirt/qemu/networks/autostart/default.xml" do
  action :delete
end


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
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["neutron"]["service_user"]
keystone_service_password = node["neutron"]["service_password"]
keystone_service_url = "#{keystone_protocol}://#{keystone_host}:#{keystone_admin_port}/v2.0"
Chef::Log.info("Keystone server found at #{keystone_host}")

template "/etc/neutron/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_protocol => keystone_protocol,
    :keystone_host => keystone_host,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
end

case node[:neutron][:networking_plugin]
when "openvswitch", "cisco"
  interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
when "linuxbridge"
  interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
end

# Hardcode for now.
template "/etc/neutron/l3_agent.ini" do
  source "l3_agent.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:neutron][:debug],
    :interface_driver => interface_driver,
    :use_namespaces => "True",
    :handle_internal_only_routers => "True",
    :metadata_port => 9697,
    :send_arp_for_ha => 3,
    :periodic_interval => 40,
    :periodic_fuzzy_delay => 5
  )
end

dns_list = node[:dns][:forwarders].join(" ")

# Ditto
template "/etc/neutron/dhcp_agent.ini" do
  source "dhcp_agent.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:neutron][:debug],
    :interface_driver => interface_driver,
    :use_namespaces => "True",
    :resync_interval => 5,
    :dhcp_driver => "neutron.agent.linux.dhcp.Dnsmasq",
    :dhcp_domain => node[:neutron][:dhcp_domain],
    :enable_isolated_metadata => "True",
    :enable_metadata_network => "False",
    :nameservers => dns_list
  )
end

# Double ditto.

novas = search(:node, "roles:nova-multi-controller") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end
# we use an IP address here, and not nova[:fqdn] because nova-metadata doesn't use SSL
# and because it listens on this specific IP address only (so we don't want to use a name
# that could resolve to 127.0.0.1).
metadata_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(nova, "admin").address
metadata_port = "8775"
metadata_proxy_shared_secret = (nova[:nova][:neutron_metadata_proxy_shared_secret] rescue '')

template "/etc/neutron/metadata_agent.ini" do
  source "metadata_agent.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:neutron][:debug],
    :auth_url => keystone_service_url,
    :auth_region => "RegionOne",
    :admin_tenant_name => keystone_service_tenant,
    :admin_user => keystone_service_user,
    :admin_password => keystone_service_password,
    :nova_metadata_host => metadata_host,
    :nova_metadata_port => metadata_port,
    :metadata_proxy_shared_secret => metadata_proxy_shared_secret
  )
end

service node[:neutron][:platform][:metadata_agent_name] do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/metadata_agent.ini]")
end

case node[:neutron][:networking_plugin]
when "openvswitch"
  directory "/etc/neutron/plugins/openvswitch/" do
     mode 00775
     owner node[:neutron][:platform][:user]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end
when "cisco"
  directory "/etc/neutron/plugins/cisco/" do
     mode 00775
     owner node[:neutron][:platform][:user]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end
when "linuxbridge"
  directory "/etc/neutron/plugins/linuxbridge/" do
     mode 00775
     owner node[:neutron][:platform][:user]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end
end

if node[:neutron][:networking_plugin] == "cisco"
  include_recipe "neutron::cisco_support"
end

unless node[:neutron][:use_gitrepo]
  # no need to create link for plugin_cfg_path here; already handled in
  # common_install recipe
  service node[:neutron][:platform][:service_name] do
    supports :status => true, :restart => true
    action :enable
    # no subscribes for :restart; this is handled by the
    # "mark neutron-server as restart for post-install" ruby_block
  end
else
  service neutron_service_name do
    supports :status => true, :restart => true
    action :enable
    subscribes :restart, resources("template[/etc/neutron/api-paste.ini]")
    subscribes :restart, resources("template[#{plugin_cfg_path}]")
    subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  end
end

service node[:neutron][:platform][:dhcp_agent_name] do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/dhcp_agent.ini]")
end

service node[:neutron][:platform][:l3_agent_name] do
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/l3_agent.ini]")
end

# This is some bad hack: we need to restart the server and the agent before
# post_install_conf if there was a configuration change. We cannot use
# :immediately to directly restart the services earlier, because they would be
# started before all configuration files get written.
services_to_restart = []

ruby_block "mark the dhcp-agent as restart for post-install" do
  block do
    unless services_to_restart.include?(node[:neutron][:platform][:dhcp_agent_name])
      services_to_restart << node[:neutron][:platform][:dhcp_agent_name]
    end
  end
  action :nothing
  subscribes :create, resources("template[/etc/neutron/neutron.conf]"), :immediately
  subscribes :create, resources("template[/etc/neutron/dhcp_agent.ini]"), :immediately
end

ruby_block "mark the l3-agent as restart for post-install" do
  block do
    unless services_to_restart.include?(node[:neutron][:platform][:l3_agent_name])
      services_to_restart << node[:neutron][:platform][:l3_agent_name]
    end
  end
  action :nothing
  subscribes :create, resources("template[/etc/neutron/l3_agent.ini]"), :immediately
  subscribes :create, resources("template[/etc/neutron/neutron.conf]"), :immediately
end

ruby_block "mark neutron-server as restart for post-install" do
  block do
    _service_name = node[:neutron][:platform][:service_name]
    _service_name = neutron_service_name if node[:neutron][:use_gitrepo]
    unless services_to_restart.include?(_service_name)
      services_to_restart << _service_name
    end
  end
  action :nothing
  subscribes :create, resources("template[/etc/neutron/api-paste.ini]"), :immediately
  subscribes :create, resources("link[#{plugin_cfg_path}]"), :immediately unless node[:neutron][:use_gitrepo]
  subscribes :create, resources("template[#{plugin_cfg_path}]"), :immediately if node[:neutron][:use_gitrepo]
  subscribes :create, resources("template[/etc/neutron/neutron.conf]"), :immediately
end

ruby_block "mark neutron-agent as restart for post-install" do
  block do
    unless services_to_restart.include?(neutron_agent)
      services_to_restart << neutron_agent
    end
  end
  action :nothing
  subscribes :create, resources("link[#{plugin_cfg_path}]"), :immediately unless node[:neutron][:use_gitrepo]
  subscribes :create, resources("template[#{plugin_cfg_path}]"), :immediately if node[:neutron][:use_gitrepo]
  subscribes :create, resources("template[/etc/neutron/neutron.conf]"), :immediately
end

ruby_block "restart services for post-install" do
  block do
    services_to_restart.each do |service|
      Chef::Log.info("Restarting #{service}")
      %x{/etc/init.d/#{service} restart}
    end
  end
end

include_recipe "neutron::post_install_conf"

node[:neutron][:monitor] = {} if node[:neutron][:monitor].nil?
node[:neutron][:monitor][:svcs] = [] if node[:neutron][:monitor][:svcs].nil?
node[:neutron][:monitor][:svcs] << ["neutron"] if node[:neutron][:monitor][:svcs].empty?
node.save

