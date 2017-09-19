# Copyright 2013 Dell, Inc.
# Copyright 2014-2015 SUSE Linux GmbH
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
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
  nova_compute_ha_enabled = node[:nova][:ha][:compute][:enabled]
else
  neutron = node
  nova_compute_ha_enabled = false
end

ironic_net = Barclamp::Inventory.get_network_definition(node, "ironic")

# Disable rp_filter
ruby_block "edit /etc/sysctl.conf for rp_filter" do
  block do
    rc = Chef::Util::FileEdit.new("/etc/sysctl.conf")
    rc.search_file_replace_line(/^net.ipv4.conf.all.rp_filter/, "net.ipv4.conf.all.rp_filter = 0")
    rc.write_file
  end
  only_if { node[:platform_family] == "suse" }
end

directory "create /etc/sysctl.d for disable-rp_filter" do
  path "/etc/sysctl.d"
  mode "755"
end

disable_rp_filter_file = "/etc/sysctl.d/50-neutron-disable-rp_filter.conf"
cookbook_file disable_rp_filter_file do
  source "sysctl-disable-rp_filter.conf"
  mode "0644"
end

bash "reload disable-rp_filter-sysctl" do
  code "/sbin/sysctl -e -q -p #{disable_rp_filter_file}"
  action :nothing
  subscribes :run, resources(cookbook_file: disable_rp_filter_file), :delayed
end

neighbour_table_overflow_file = "/etc/sysctl.d/50-neutron-neighbour-table-overflow.conf"
cookbook_file neighbour_table_overflow_file do
  source "sysctl-neighbour-table-overflow.conf"
  mode "0644"
end

bash "reload neighbour-table-overflow.conf" do
  code "/sbin/sysctl -e -q -p #{neighbour_table_overflow_file}"
  action :nothing
  subscribes :run, resources(cookbook_file: neighbour_table_overflow_file), :delayed
end

if neutron[:neutron][:networking_plugin] == "ml2" &&
    neutron[:neutron][:ml2_mechanism_drivers].include?("vmware_dvs") &&
    node.roles.include?("nova-compute-vmware")

  include_recipe "neutron::vmware_dvs_agents"

  # No L2/L3 agents need to be installed on DVS integrated
  # VMware compute nodes aside from the neutron-dvs agent
  # This check is sufficient, because a node cannot be assigned
  # the nova-compute-vmware and nova-compute-<something-else> roles
  # at the same time. The only exception is if DVR is enabled,
  # when L2/L3 agents are required.
  unless neutron[:neutron][:use_dvr] || node.roles.include?("neutron-network")
    return # skip everything else in this recipe
  end
end

if neutron[:neutron][:networking_plugin] == "ml2" &&
    (neutron[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2") ||
    neutron[:neutron][:ml2_mechanism_drivers].include?("apic_gbp"))
  include_recipe "neutron::cisco_apic_agents"
  return # skip anything else in this recipe
end

multiple_external_networks = !neutron[:neutron][:additional_external_networks].empty?

# openvswitch configuration specific to ML2
if neutron[:neutron][:networking_plugin] == "ml2" &&
   neutron[:neutron][:ml2_mechanism_drivers].include?("openvswitch")

  # Install the package now as neutron-ovs-cleanup service is shipped with this
  package node[:neutron][:platform][:ovs_agent_pkg]

  if node[:platform_family] == "debian"
    # Arrange for neutron-ovs-cleanup to be run on bootup of compute nodes only
    unless neutron.name == node.name
      cookbook_file "/etc/init.d/neutron-ovs-cleanup" do
        source "neutron-ovs-cleanup"
        mode 00755
      end
      link "/etc/rc2.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end
      link "/etc/rc3.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end
      link "/etc/rc4.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end
      link "/etc/rc5.d/S20neutron-ovs-cleanup" do
        to "../init.d/neutron-ovs-cleanup"
      end
    end
  else
    # Note: this must not be started! This service only makes sense on boot.
    service "neutron-ovs-cleanup" do
      service_name "openstack-neutron-ovs-cleanup" if node[:platform_family] == "suse"
      action [:enable]
    end
  end
end

# Cleanup the ovs-usurp init scripts that might still be existing from an old
# install (before the network barclamp created the ovs-bridge configuration).
unless (node[:platform] == "suse" && node[:platform_version].to_f < 12.0)
  bridges = ["br-public", "br-fixed"]
  neutron[:neutron][:additional_external_networks].each do |net|
    bridges << "br-#{net}"
  end
  bridges.each do |name|
    service "ovs-usurp-config-#{name}" do
      # There's no need to stop anything here. I might even cut us off the
      # network.
      action [:disable]
      only_if { ::File.exist?("/etc/init.d/ovs-usurp-config-#{name}") }
    end
    file "/etc/init.d/ovs-usurp-config-#{name}" do
      action :delete
    end
  end
end

neutron_network_ha = node.roles.include?("neutron-network") && neutron[:neutron][:ha][:network][:enabled]

# ML2 configuration: L2 agent and L3 agent
if neutron[:neutron][:networking_plugin] == "ml2"
  ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]
  if node.roles.include?("nova-compute-zvm")
    ml2_mech_drivers.push("zvm")
  end
  ml2_type_drivers = neutron[:neutron][:ml2_type_drivers]

  case
  when ml2_mech_drivers.include?("zvm")
    package node[:neutron][:platform][:zvm_agent_pkg]

    neutron_agent = node[:neutron][:platform][:zvm_agent_name]
    agent_config_path = "/etc/neutron/plugins/zvm/neutron_zvm_plugin.ini"
    physnet = node[:crowbar_wall][:network][:nets][:nova_fixed].first
    interface_mappings = "physnet1:" + physnet

  when ml2_mech_drivers.include?("openvswitch")
    # package is already installed
    neutron_agent = node[:neutron][:platform][:ovs_agent_name]
    agent_config_path = "/etc/neutron/plugins/ml2/openvswitch_agent.ini"
    interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
    bridge_mappings = []

    if ml2_type_drivers.include?("vlan")
      bridge = node[:crowbar_wall][:network][:nets][:nova_fixed].last
      bridge_mappings.push("physnet1:" + bridge)
    end

    if neutron[:neutron][:use_dvr] || node.roles.include?("neutron-network")
      external_networks = ["nova_floating"]
      external_networks.concat(node[:neutron][:additional_external_networks])
      ext_physnet_map = NeutronHelper.get_neutron_physnets(node, external_networks)
      external_networks.each do |net|
        ext_iface = node[:crowbar_wall][:network][:nets][net].last
        # we can't do "floating:br-public, physnet1:br-public"; this also means
        # that all relevant nodes here must have a similar bridge_mappings
        # setting
        next if ext_physnet_map[net] == "physnet1"
        bridge_mappings.push(ext_physnet_map[net] + ":" + ext_iface)
      end
    end

    if (node.roles & ["ironic-server", "nova-compute-ironic"]).any? ||
        (ironic_net && node.roles.include?("neutron-network"))
      bridge_mappings.push("ironic:br-ironic")
    end

    bridge_mappings = bridge_mappings.join(", ")
  when ml2_mech_drivers.include?("linuxbridge")
    package node[:neutron][:platform][:lb_agent_pkg]

    neutron_agent = node[:neutron][:platform][:lb_agent_name]
    agent_config_path = "/etc/neutron/plugins/ml2/linuxbridge_agent.ini"
    interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
    interface_mappings = []

    if ml2_type_drivers.include?("vlan")
      physnet = node[:crowbar_wall][:network][:nets][:nova_fixed].first
      interface_mappings.push("physnet1:" + physnet)
    end

    if neutron[:neutron][:use_dvr] || node.roles.include?("neutron-network")
      external_networks = ["nova_floating"]
      external_networks.concat(node[:neutron][:additional_external_networks])
      ext_physnet_map = NeutronHelper.get_neutron_physnets(node, external_networks)
      external_networks.each do |net|
        ext_iface = node[:crowbar_wall][:network][:nets][net].last
        next if ext_physnet_map[net] == "physnet1"
        interface_mappings.push(ext_physnet_map[net] + ":" + ext_iface)
      end
    end

    interface_mappings = interface_mappings.join(", ")
  end

  # include neutron::common_config only now, after we've installed packages
  include_recipe "neutron::common_config"

  # L2 agent
  case
  when ml2_mech_drivers.include?("zvm")
    # accessing the network definition directly, since the node is not using
    # this network
    fixed_net_def = Barclamp::Inventory.get_network_definition(neutron, "nova_fixed")
    vlan_start = fixed_net_def["vlan"]
    num_vlans = neutron[:neutron][:num_vlans]
    vlan_end = [vlan_start + num_vlans - 1, 4094].min

    template agent_config_path do
      cookbook "neutron"
      source "neutron_zvm_plugin.ini.erb"
      owner "root"
      group node[:neutron][:platform][:group]
      mode "0640"
      variables(
        zvm: neutron[:neutron][:zvm],
        vlan_start: vlan_start,
        vlan_end: vlan_end,
      )
    end
  when ml2_mech_drivers.include?("openvswitch")
    directory "/etc/neutron/plugins/openvswitch/" do
      mode 00755
      owner "root"
      group node[:neutron][:platform][:group]
      action :create
      recursive true
      not_if { node[:platform_family] == "suse" }
    end

    template agent_config_path do
      cookbook "neutron"
      source "openvswitch_agent.ini.erb"
      owner "root"
      group node[:neutron][:platform][:group]
      mode "0640"
      variables(
        ml2_type_drivers: ml2_type_drivers,
        tunnel_types: ml2_type_drivers.select { |t| ["vxlan", "gre"].include?(t) },
        use_l2pop: neutron[:neutron][:use_l2pop] &&
            (ml2_type_drivers.include?("gre") || ml2_type_drivers.include?("vxlan")),
        dvr_enabled: neutron[:neutron][:use_dvr],
        tunnel_csum: neutron[:neutron][:ovs][:tunnel_csum],
        ovsdb_interface: neutron[:neutron][:ovs][:ovsdb_interface],
        bridge_mappings: bridge_mappings
      )
    end
  when ml2_mech_drivers.include?("linuxbridge")
    directory "/etc/neutron/plugins/linuxbridge/" do
      mode 00755
      owner "root"
      group node[:neutron][:platform][:group]
      action :create
      recursive true
      not_if { node[:platform_family] == "suse" }
    end

    template agent_config_path do
      cookbook "neutron"
      source "linuxbridge_agent.ini.erb"
      owner "root"
      group node[:neutron][:platform][:group]
      mode "0640"
      variables(
        ml2_type_drivers: ml2_type_drivers,
        vxlan_mcast_group: neutron[:neutron][:vxlan][:multicast_group],
        use_l2pop: neutron[:neutron][:use_l2pop] && ml2_type_drivers.include?("vxlan"),
        interface_mappings: interface_mappings
       )
    end
  end

  service neutron_agent do
    action [:enable, :start]
    subscribes :restart, resources("template[#{agent_config_path}]")
    subscribes :restart, resources(template: node[:neutron][:config_file])
    if neutron_network_ha || nova_compute_ha_enabled
      provider Chef::Provider::CrowbarPacemakerService
    end
    if nova_compute_ha_enabled
      supports no_crm_maintenance_mode: true
    else
      supports status: true, restart: true
    end
  end

  # L3 agent
  if neutron[:neutron][:use_dvr] || node.roles.include?("neutron-network")
    pkgs = [node[:neutron][:platform][:l3_agent_pkg]] + \
           node[:neutron][:platform][:pkgs_fwaas]
    pkgs.each { |p| package p }

    template node[:neutron][:l3_agent_config_file] do
      source "l3_agent.ini.erb"
      owner "root"
      group node[:neutron][:platform][:group]
      mode "0640"
      variables(
        debug: neutron[:neutron][:debug],
        interface_driver: interface_driver,
        handle_internal_only_routers: "True",
        metadata_port: 9697,
        periodic_interval: 40,
        periodic_fuzzy_delay: 5,
        dvr_enabled: neutron[:neutron][:use_dvr],
        dvr_mode: node.roles.include?("neutron-network") ? "dvr_snat" : "dvr"
      )
    end

    service node[:neutron][:platform][:l3_agent_name] do
      action [:enable, :start]
      subscribes :restart, resources(template: node[:neutron][:config_file])
      subscribes :restart, resources(template: node[:neutron][:l3_agent_config_file])
      if neutron_network_ha || nova_compute_ha_enabled
        provider Chef::Provider::CrowbarPacemakerService
      end
      if nova_compute_ha_enabled
        supports no_crm_maintenance_mode: true
      else
        supports status: true, restart: true
      end
    end
  end
end

# Metadata agent
if neutron[:neutron][:use_dvr] || node.roles.include?("neutron-network")
  neutron_metadata do
    use_cisco_apic_ml2_driver false
    neutron_node_object neutron
    neutron_network_ha neutron_network_ha
    nova_compute_ha_enabled nova_compute_ha_enabled
  end
end

# VMware specific code
if neutron[:neutron][:networking_plugin] == "vmware"
  include_recipe "neutron::vmware_support"
  # We don't need anything more installed or configured on
  # compute nodes except openvswitch packages with stt.
  # For NSX plugin no neutron packages are needed.
end
