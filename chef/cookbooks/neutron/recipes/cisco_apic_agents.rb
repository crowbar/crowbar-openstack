#
# Copyright 2016 SUSE Linux GmBH
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

neutron = nil
if node.attribute?(:cookbook) && node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' \
                                    for nova not found")
else
  neutron = node
end

ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]
ml2_type_drivers = neutron[:neutron][:ml2_type_drivers]

return unless ml2_mech_drivers.include?("cisco_apic_ml2") ||
    ml2_mech_drivers.include?("apic_gbp")

node[:neutron][:platform][:cisco_apic_pkgs].each { |p| package p }

# We may need to review the ovs packages once we have better
# clarity on what packages and kernel modules will be supported
# for APIC integration.(eg: current version of APIC requires
# openvswitch 2.4 with upstream kmp modules instead of kernel
# provided modules). This will install default openvswitch
# packages until the correct set is finalized.
node[:network][:ovs_pkgs].each { |p| package p }

service node[:network][:ovs_service] do
  supports status: true, restart: true
  action [:start, :enable]
end

if node.roles.include?("neutron-network")
  # Explicitly stop and disable l3 and metadata agents if APIC is
  # enabled on network node
  service node[:neutron][:platform][:metadata_agent_name] do
    action [:disable, :stop]
  end

  service node[:neutron][:platform][:l3_agent_name] do
    action [:disable, :stop]
  end
end

# apply configurations to compute node
node[:neutron][:platform][:cisco_opflex_pkgs].each { |p| package p }

service "lldpd" do
  action [:enable, :start]
end
utils_systemd_service_restart "lldpd"

# include neutron::common_config only now, after we've installed packages
include_recipe "neutron::common_config"

# Agent configurations for Cisco APIC driver
# The ACI setup for OpenStack releases before Pike use "of_interface" options
# set to "ovs-ofctl". This option has been deprecated in Pike and removed
# from this config file for Pike. It is still included in Newton (Cloud7)
agent_config_path = "/etc/neutron/plugins/ml2/openvswitch_agent.ini"
template agent_config_path do
  cookbook "neutron"
  source "openvswitch_agent.ini.erb"
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  variables(
    ml2_type_drivers: ml2_type_drivers,
    ml2_mech_drivers: ml2_mech_drivers,
    tunnel_types: "",
    enable_tunneling: false,
    use_l2pop: false,
    dvr_enabled: false,
    of_interface: "ovs-ofctl",
    ovsdb_interface: neutron[:neutron][:ovs][:ovsdb_interface],
    bridge_mappings: ""
  )
end

# Update config file from template
opflex_agent_conf = "/etc/opflex-agent-ovs/conf.d/10-opflex-agent-ovs.conf"
apic = neutron[:neutron][:apic]
opflex_list = apic[:opflex].select { |i| i[:nodes].include? node[:hostname] }
opflex_list.any? || raise("Opflex instance not found for node '#{node[:hostname]}'")
opflex_list.one? || raise("Multiple opflex instances found for node '#{node[:hostname]}'")
opflex = opflex_list.first
template opflex_agent_conf do
  cookbook "neutron"
  source "10-opflex-agent-ovs.conf.erb"
  mode "0755"
  owner "root"
  group neutron[:neutron][:platform][:group]
  variables(
    opflex_apic_domain_name: neutron[:neutron][:apic][:system_id],
    hostname: node[:hostname],
    socketgroup: neutron[:neutron][:platform][:group],
    opflex_peer_ip: opflex[:peer_ip],
    opflex_peer_port: opflex[:peer_port],
    opflex_vxlan_encap_iface: opflex[:vxlan][:encap_iface],
    opflex_vxlan_uplink_iface: opflex[:vxlan][:uplink_iface],
    opflex_vxlan_uplink_vlan: opflex[:vxlan][:uplink_vlan],
    opflex_vxlan_remote_ip: opflex[:vxlan][:remote_ip],
    opflex_vxlan_remote_port: opflex[:vxlan][:remote_port],
    # TODO(mmnelemane) : update VLAN encapsulation config when it works.
    # Currently set to VXLAN by default but can be modified from proposal.
    ml2_type_drivers: ml2_type_drivers
  )
end

neutron_metadata do
  use_cisco_apic_ml2_driver true
  neutron_node_object neutron
end

service "neutron-opflex-agent" do
  action [:enable, :start]
  subscribes :restart, resources("template[#{agent_config_path}]")
end
utils_systemd_service_restart "neutron-opflex-agent"

service "agent-ovs" do
  action [:enable, :start]
  subscribes :restart, resources("template[#{opflex_agent_conf}]")
end
utils_systemd_service_restart "agent-ovs"
