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
  neutrons = search(:node, "roles:neutron-server AND \
                    roles:neutron-config-#{node[:nova][:neutron_instance]}")
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
if node.roles.include?("nova-compute-kvm")
  node[:neutron][:platform][:cisco_opflex_pkgs].each { |p| package p }

  service "lldpd" do
    action [:enable, :start]
  end

  # include neutron::common_config only now, after we've installed packages
  include_recipe "neutron::common_config"

  # Agent configurations for Cisco APIC driver
  agent_config_path = "/etc/neutron/plugins/ml2/openvswitch_agent.ini"
  template agent_config_path do
    cookbook "neutron"
    source "openvswitch_agent.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      ml2_type_drivers: ml2_type_drivers,
      tunnel_types: "",
      use_l2pop: false,
      dvr_enabled: false,
      bridge_mappings: ""
    )
  end

  # Update config file from template
  opflex_agent_conf = "/etc/opflex-agent-ovs/conf.d/10-opflex-agent-ovs.conf"
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
      opflex_peer_ip: neutron[:neutron][:apic][:opflex][:peer_ip],
      opflex_peer_port: neutron[:neutron][:apic][:opflex][:peer_port],
      opflex_vxlan_encap_iface: neutron[:neutron][:apic][:opflex][:vxlan][:encap_iface],
      opflex_vxlan_uplink_iface: neutron[:neutron][:apic][:opflex][:vxlan][:uplink_iface],
      opflex_vxlan_uplink_vlan: neutron[:neutron][:apic][:opflex][:vxlan][:uplink_vlan],
      opflex_vxlan_remote_ip: neutron[:neutron][:apic][:opflex][:vxlan][:remote_ip],
      opflex_vxlan_remote_port: neutron[:neutron][:apic][:opflex][:vxlan][:remote_port],
      # TODO(mmnelemane) : update VLAN encapsulation config when it works.
      # Currently set to VXLAN by default but can be modified from proposal.
      ml2_type_drivers: neutron[:neutron][:ml2_type_drivers]
    )
  end

  service "neutron-opflex-agent" do
    action [:enable, :start]
    subscribes :restart, resources("template[#{agent_config_path}]")
  end

  service "agent-ovs" do
    action [:enable, :start]
    subscribes :restart, resources("template[#{opflex_agent_conf}]")
  end
end
