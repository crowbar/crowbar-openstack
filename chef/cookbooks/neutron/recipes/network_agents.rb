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

package node[:neutron][:platform][:dhcp_agent_pkg]
package node[:neutron][:platform][:metering_agent_pkg]

if node[:neutron][:use_lbaas]
  if node[:neutron][:use_lbaasv2] && [nil, "", "haproxy"].include?(node[:neutron][:lbaasv2_driver])
    package node[:neutron][:platform][:lbaas_agent_pkg]
  else
    package node[:neutron][:platform][:lbaasv2_agent_pkg]
  end
end

# Enable ip forwarding on network node for SLE11
ruby_block "edit /etc/sysconfig/sysctl for IP_FORWARD" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/sysconfig/sysctl")
    rc.search_file_replace_line(/^IP_FORWARD=/, 'IP_FORWARD="yes"')
    rc.write_file
  end
  only_if { node[:platform] == "suse" && node[:platform_version].to_f < 12.0 }
end

# Enable ip forwarding on network node for new SUSE platforms
ruby_block "edit /etc/sysctl.d/99-sysctl.conf for net.ipv4.ip_forward" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/sysctl.d/99-sysctl.conf")
    rc.search_file_replace_line(/^net.ipv4.ip_forward =/, "net.ipv4.ip_forward = 1")
    rc.write_file
  end
  only_if { node[:platform_family] == "suse" && (node[:platform] != "suse" || node[:platform_version].to_f >= 12.0) }
end

# The rest of this logic will be compatible for all the platforms.
# There is an overlap here, but will not cause inferference (the
# variable `net.ipv4.ip_forward` is set to 1 in two files,
# 99-sysctl.conf and 50-neutron-enable-ip_forward.conf)

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
  subscribes :run, resources(cookbook_file: enable_ip_forward_file), :delayed
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
when "ml2"
  ml2_mech_drivers = node[:neutron][:ml2_mechanism_drivers]
  case
  when ml2_mech_drivers.include?("openvswitch") ||
    ml2_mech_drivers.include?("cisco_apic_ml2") ||
    ml2_mech_drivers.include?("apic_gbp")
    interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
  when ml2_mech_drivers.include?("linuxbridge")
    interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
  end
when "vmware"
  interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
end

template "/etc/neutron/metering_agent.ini" do
  cookbook "neutron"
  source "metering_agent.ini.erb"
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  variables(
    debug: node[:neutron][:debug],
    interface_driver: interface_driver,
    use_namespaces: "True"
  )
end

# Delete pre-existing configuration file.
file "/etc/neutron/dnsmasq-neutron.conf" do
  action :delete
end

dns_list = node[:dns][:forwarders].join(",")

template "/etc/neutron/dhcp_agent.ini" do
  source "dhcp_agent.ini.erb"
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  variables(
    debug: node[:neutron][:debug],
    interface_driver: interface_driver,
    use_namespaces: "True",
    resync_interval: 5,
    dhcp_driver: "neutron.agent.linux.dhcp.Dnsmasq",
    dhcp_domain: node[:neutron][:dhcp_domain],
    enable_isolated_metadata: "True",
    enable_metadata_network: "False",
    nameservers: dns_list
  )
end

if node[:neutron][:use_lbaas] &&
    (!node[:neutron][:use_lbaasv2] || [nil, "", "haproxy"].include?(node[:neutron][:lbaasv2_driver]))
  template "/etc/neutron/lbaas_agent.ini" do
    cookbook "neutron"
    source "lbaas_agent.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      debug: node[:neutron][:debug],
      interface_driver: interface_driver,
      user_group: node[:neutron][:platform][:lbaas_haproxy_group],
      device_driver: "neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver"
    )
  end
end

ha_enabled = node[:neutron][:ha][:network][:enabled]

service node[:neutron][:platform][:metering_agent_name] do
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/metering_agent.ini]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

if node[:neutron][:use_lbaas] &&
    (!node[:neutron][:use_lbaasv2] || [nil, "", "haproxy"].include?(node[:neutron][:lbaasv2_driver]))
  lbaas_agent = if node[:neutron][:use_lbaasv2]
    node[:neutron][:platform][:lbaasv2_agent_name]
  else
    node[:neutron][:platform][:lbaas_agent_name]
  end
  service lbaas_agent do
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
    subscribes :restart, resources("template[/etc/neutron/lbaas_agent.ini]")
    provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  end
end

service node[:neutron][:platform][:dhcp_agent_name] do
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  subscribes :restart, resources("template[/etc/neutron/dhcp_agent.ini]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

# Fix broken MTU on upgrade from Juno (bsc#968426)
# This is only an issue on upgrade (hence the check for an existence of an old
# file) and for tunnels (gre/vxlan -- was only available with ovs)
if !node[:neutron][:network_mtu_fix] &&
    File.exist?("/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini.rpmsave")
  if node[:neutron][:networking_plugin] == "ml2" && ml2_mech_drivers.include?("openvswitch")
    cookbook_file "crowbar-fix-tunnel-networks-mtu" do
      path "/usr/bin/crowbar-fix-tunnel-networks-mtu"
      mode "0755"
    end

    neutron_server_node = if node.roles.include?("neutron-server")
      node
    else
      search(:node, "roles:neutron-server").first
    end

    execute "fix mtu of tunnel networks" do
      command "/usr/bin/crowbar-fix-tunnel-networks-mtu \
        #{neutron_server_node[:neutron][:db][:sql_connection]}"
      action :run
      # restart local dhcp agent to get dnsmasq restarted so it advertises the
      # correct mtu; this is why we run this on all nodes even with HA
      notifies :restart, "service[#{node[:neutron][:platform][:dhcp_agent_name]}]"
    end
  end

  ruby_block "mark node for having the networks mtus fixed (bsc#968426)" do
    block do
      node[:neutron][:network_mtu_fix] = true
      node.save
    end
  end
end

if ha_enabled
  log "HA support for neutron agents is enabled"
  include_recipe "neutron::network_agents_ha"
else
  log "HA support for neutron agents is disabled"
end
