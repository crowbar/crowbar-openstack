# Copyright 2011 Dell, Inc.
# Copyright 2014 SUSE
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

include_recipe "neutron::common_agent"


unless node[:neutron][:use_gitrepo]
  pkgs = [ node[:neutron][:platform][:dhcp_agent_pkg], node[:neutron][:platform][:l3_agent_pkg], node[:neutron][:platform][:metadata_agent_pkg], node[:neutron][:platform][:metering_agent_pkg] ]
  pkgs.uniq.each { |p| package p }
else
  neutron_path = "/opt/neutron"
  venv_path = node[:neutron][:use_virtualenv] ? "#{neutron_path}/.venv" : nil

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
  link_service "neutron-metering-agent" do
    virtualenv venv_path
    bin_name "neutron-metering-agent --config-dir /etc/neutron/ --config-file /etc/neutron/metering_agent.ini"
  end
end


# Enable ip forwarding on network node
ruby_block "edit /etc/sysconfig/sysctl for IP_FORWARD" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/sysconfig/sysctl")
    rc.search_file_replace_line(/^IP_FORWARD=/, 'IP_FORWARD="yes"')
    rc.write_file
  end
  only_if { node[:platform] == "suse" }
end

directory "create /etc/sysctl.d for enable-ip_forward" do
  path "/etc/sysctl.d"
  mode "755"
end

enable_ip_forward_file = "/etc/sysctl.d/50-neutron-enable-ip_forward.conf"
cookbook_file enable_ip_forward_file do
  source "sysctl-enable-ip_forward.conf"
  mode "0644"
end

bash "reload enable-ip_forward-sysctl" do
  code "/sbin/sysctl -e -q -p #{enable_ip_forward_file}"
  action :nothing
  subscribes :run, resources(:cookbook_file=> enable_ip_forward_file), :delayed
end


# Kill all the libvirt default networks.
execute "Destroy the libvirt default network" do
  command "virsh net-destroy default"
  only_if "virsh net-list |grep default"
end

link "/etc/libvirt/qemu/networks/autostart/default.xml" do
  action :delete
end


case node[:neutron][:networking_plugin]
when "openvswitch", "cisco"
  interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
  external_network_bridge = "br-public"
when "linuxbridge"
  interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
  external_network_bridge = ""
when "vmware"
  interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
  external_network_bridge = ""
end


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
    :periodic_fuzzy_delay => 5,
    :external_network_bridge => external_network_bridge
  )
  not_if { node[:neutron][:networking_plugin] == "vmware" }
end

template "/etc/neutron/metering_agent.ini" do
  cookbook "neutron"
  source "metering_agent.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:neutron][:debug],
    :interface_driver => interface_driver,
    :use_namespaces => "True"
  )
end

dns_list = node[:dns][:forwarders].join(" ")

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


#TODO: nova should depend on neutron, but neutron depend on nova a bit, so we have to do somthing with this
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
metadata_host = CrowbarHelper.get_host_for_admin_url(nova, (nova[:nova][:ha][:enabled] rescue false))
metadata_port = "8775"
metadata_proxy_shared_secret = (nova[:nova][:neutron_metadata_proxy_shared_secret] rescue '')

keystone_settings = NeutronHelper.keystone_settings(node)

template "/etc/neutron/metadata_agent.ini" do
  source "metadata_agent.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :debug => node[:neutron][:debug],
    :keystone_settings => keystone_settings,
    :auth_region => "RegionOne",
    :nova_metadata_host => metadata_host,
    :nova_metadata_port => metadata_port,
    :metadata_proxy_shared_secret => metadata_proxy_shared_secret
  )
end

ha_enabled = node[:neutron][:ha][:l3][:enabled]

service node[:neutron][:platform][:l3_agent_name] do
  service_name "neutron-l3-agent" if node[:neutron][:use_gitrepo]
  supports :status => true, :restart => true
  action ha_enabled ? :disable : [:enable, :start]
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/l3_agent.ini]")
  not_if { node[:neutron][:networking_plugin] == "vmware" }
end

service node[:neutron][:platform][:metering_agent_name] do
  service_name "neutron-metering-agent" if node[:neutron][:use_gitrepo]
  supports :status => true, :restart => true
  action ha_enabled ? :disable : [:enable, :start]
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/metering_agent.ini]")
end

service node[:neutron][:platform][:dhcp_agent_name] do
  service_name "neutron-dhcp-agent" if node[:neutron][:use_gitrepo]
  supports :status => true, :restart => true
  action ha_enabled ? :disable : [:enable, :start]
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/dhcp_agent.ini]")
end

service node[:neutron][:platform][:metadata_agent_name] do
  service_name "neutron-metadata-agent" if node[:neutron][:use_gitrepo]
  supports :status => true, :restart => true
  action ha_enabled ? :disable : [:enable, :start]
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/metadata_agent.ini]")
end

if ha_enabled
  log "HA support for neutron-l3-agent is enabled"
  include_recipe "neutron::l3_ha"
else
  log "HA support for neutron-l3-agent is disabled"
end
