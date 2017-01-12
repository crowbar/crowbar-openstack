#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "ipaddr"

class NeutronService < PacemakerServiceObject
  def initialize(thelogger)
    super(thelogger)
    @bc_name = "neutron"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def self.networking_plugins_valid
    ["ml2", "vmware"]
  end

  def self.networking_ml2_type_drivers_valid
    ["vlan", "gre", "vxlan"]
  end

  def self.networking_ml2_mechanism_drivers_valid
    ["linuxbridge", "openvswitch", "cisco_nexus"]
  end

  class << self
    def role_constraints
      {
        "neutron-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "neutron-network" => {
          "unique" => false,
          "count" => 1,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "database", "inst" => role.default_attributes["neutron"]["database_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["neutron"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["neutron"]["keystone_instance"] }
    answer
  end

  def save_proposal!(prop, options = {})
    # Fill in missing defaults for infoblox grid configurations
    if prop.raw_data[:attributes][:neutron][:use_infoblox]
      prop.raw_data[:attributes][:neutron][:infoblox][:grids].each do |grid|
        defaults = prop.raw_data["attributes"]["neutron"]["infoblox"]["grid_defaults"]
        defaults.each_key.each do |d|
          unless grid.key?(d)
            grid[d] = defaults[d]
          end
        end
      end
    end

    super(prop, options)
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    controller_nodes = nodes.select { |n| n.intended_role == "controller" }
    controller_node = controller_nodes.first
    controller_node ||= nodes.first

    network_nodes = nodes.select { |n| n.intended_role == "network" }
    network_nodes = [controller_node] if network_nodes.empty?

    base["deployment"]["neutron"]["elements"] = {
        "neutron-server" => [controller_node[:fqdn]],
        "neutron-network" => network_nodes.map { |x| x[:fqdn] }
    } unless nodes.nil? or nodes.length ==0

    base["attributes"]["neutron"]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    base
  end

  def validate_gre(gre_settings)
    if gre_settings["tunnel_id_start"] < 1 || gre_settings["tunnel_id_start"] > 2147483647
      validation_error I18n.t("barclamp.#{@bc_name}.validation.start_id")
    end
    if gre_settings["tunnel_id_end"]  < 1 || gre_settings["tunnel_id_end"] > 2147483647
      validation_error I18n.t("barclamp.#{@bc_name}.validation.end_id")
    end
    if gre_settings["tunnel_id_start"] > gre_settings["tunnel_id_end"]
      validation_error I18n.t("barclamp.#{@bc_name}.validation.end_id_higher_than_start")
    elsif gre_settings["tunnel_id_start"] == gre_settings["tunnel_id_end"]
      validation_error I18n.t("barclamp.#{@bc_name}.validation.id_too_small")
    elsif gre_settings["tunnel_id_end"] + 1 - gre_settings["tunnel_id_start"] > 1000000
      # test being done in neutron for unreasonable ranges
      validation_error I18n.t("barclamp.#{@bc_name}.validation.id_unreasonable")
    end
  end

  def validate_vxlan(vxlan_settings)
    if vxlan_settings["vni_start"] < 0 || vxlan_settings["vni_start"] > 16777215
      validation_error I18n.t("barclamp.#{@bc_name}.validation.vxlan_vni_start")
    end
    if vxlan_settings["vni_end"]  < 0 || vxlan_settings["vni_end"] > 16777215
      validation_error I18n.t("barclamp.#{@bc_name}.validation.vxlan_vni_end")
    end
    if vxlan_settings["vni_start"] > vxlan_settings["vni_end"]
      validation_error I18n.t("barclamp.#{@bc_name}.validation.end_vxlan_vni_higher_than_start")
    elsif vxlan_settings["vni_start"] == vxlan_settings["vni_end"]
      validation_error I18n.t("barclamp.#{@bc_name}.validation.vxlan_vni_higher_too_small")
    end

    mcast_group = vxlan_settings["multicast_group"]
    unless mcast_group.empty?
      begin
        IPAddr.new(mcast_group)
      rescue ArgumentError
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.no_valid_ip", mcast_group: mcast_group
        )
      end
      mcast_first = mcast_group.split(".")[0].to_i
      if mcast_first < 224 || mcast_first > 239
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.no_valid_multicast_ip", mcast_group: mcast_group
        )
      end
    end
  end

  def validate_ml2(proposal)
    ml2_mechanism_drivers = proposal["attributes"]["neutron"]["ml2_mechanism_drivers"]
    ml2_type_drivers = proposal["attributes"]["neutron"]["ml2_type_drivers"]
    ml2_type_drivers_default_provider_network = proposal["attributes"]["neutron"]["ml2_type_drivers_default_provider_network"]
    ml2_type_drivers_default_tenant_network = proposal["attributes"]["neutron"]["ml2_type_drivers_default_tenant_network"]

    ml2_type_drivers_valid = NeutronService.networking_ml2_type_drivers_valid
    ml2_mechanism_drivers_valid = NeutronService.networking_ml2_mechanism_drivers_valid

    # at least one ml2 mech driver must be selected for ml2 as core plugin
    if ml2_mechanism_drivers.empty?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.ml2_mechanism")
    end

    # only allow valid ml2 mechanism drivers
    ml2_mechanism_drivers.each do |drv|
      next if ml2_mechanism_drivers_valid.include? drv
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.no_valid_ml2_mechanism",
        drv: drv,
        ml2_mechanism_drivers_valid: ml2_mechanism_drivers_valid.join(",")
      )
    end

    if ml2_mechanism_drivers.include?("linuxbridge") &&
        ml2_type_drivers.include?("gre")
      validation_error I18n.t("barclamp.#{@bc_name}.validation.linuxbridge_gre")
    end

    # cisco_nexus mech driver needs also openvswitch mech driver and vlan type driver
    if ml2_mechanism_drivers.include?("cisco_nexus") &&
        !ml2_mechanism_drivers.include?("openvswitch")
      validation_error I18n.t("barclamp.#{@bc_name}.validation.cisco_nexus_ovs")
    end

    if ml2_mechanism_drivers.include?("cisco_nexus") &&
        !ml2_type_drivers.include?("vlan")
      validation_error I18n.t("barclamp.#{@bc_name}.validation.cisco_nexus_vlan")
    end

    # for now, openvswitch and linuxbrige can't be used in parallel
    if ml2_mechanism_drivers.include?("openvswitch") &&
        ml2_mechanism_drivers.include?("linuxbridge")
      validation_error I18n.t("barclamp.#{@bc_name}.validation.openvswitch_linuxbridge")
    end

    # at least one ml2 type driver must be selected for ml2 as core plugin
    if ml2_type_drivers.empty?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.ml2_type_driver")
    end

    # only allow valid ml2 type drivers
    ml2_type_drivers.each do |drv|
      next if ml2_type_drivers_valid.include? drv
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.no_valid_ml2_type_driver",
        drv: drv,
        ml2_type_drivers_valid: ml2_type_drivers_valid.join(",")
      )
    end

    # default provider network ml2 type driver must be a driver from the selected ml2 type drivers
    # TODO(toabctl): select the ml2_type_driver automatically if used as default? Or directly check in the ui via js?
    unless ml2_type_drivers.include?(ml2_type_drivers_default_provider_network)
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.default_provider_network",
        ml2_type_drivers_default_provider_network: ml2_type_drivers_default_provider_network
      )
    end

    # default tenant network ml2 type driver must be a driver from the selected ml2 type drivers
    # TODO(toabctl): select the ml2_type_driver automatically if used as default? Or directly check in the ui via js?
    unless ml2_type_drivers.include?(ml2_type_drivers_default_tenant_network)
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.default_tentant_network_driver",
        ml2_type_drivers_default_tenant_network: ml2_type_drivers_default_tenant_network
      )
    end

    if ml2_mechanism_drivers.include?("openvswitch") && ml2_type_drivers.include?("gre")
      validate_gre proposal["attributes"]["neutron"]["gre"]
    end

    if ml2_type_drivers.include? "vxlan"
      validate_vxlan proposal["attributes"]["neutron"]["vxlan"]
    end
  end

  def validate_l2pop(proposal)
    ml2_type_drivers = proposal["attributes"]["neutron"]["ml2_type_drivers"]

    if proposal["attributes"]["neutron"]["use_l2pop"]
      unless ml2_type_drivers.include?("gre") || ml2_type_drivers.include?("vxlan")
        validation_error I18n.t("barclamp.#{@bc_name}.validation.l2_population")
      end
    end
  end

  def validate_dvr(proposal)
    plugin = proposal["attributes"]["neutron"]["networking_plugin"]
    ml2_mechanism_drivers = proposal["attributes"]["neutron"]["ml2_mechanism_drivers"]

    if proposal["attributes"]["neutron"]["use_dvr"]
      if !proposal["attributes"]["neutron"]["use_l2pop"]
        validation_error I18n.t("barclamp.#{@bc_name}.validation.dvr_requires_l2")
      end

      if plugin == "vmware"
        validation_error I18n.t("barclamp.#{@bc_name}.validation.dvr_vmware")
      end

      if ml2_mechanism_drivers.include? "linuxbridge"
        validation_error I18n.t("barclamp.#{@bc_name}.validation.dvr_linuxbridge")
      end

    end
  end

  def validate_external_networks(external_networks)
    net_svc = NetworkService.new @logger
    network_proposal = Proposal.find_by(barclamp: net_svc.bc_name, name: "default")
    blacklist = ["bmc", "bmc_admin", "admin", "nova_fixed", "nova_floating",
                 "os_sdn", "public", "storage"]

    external_networks.each do |ext_net|
      # Exclude a few default networks from network.json from being used as
      # additional external networks in neutron
      if blacklist.include? ext_net
        validation_error I18n.t("barclamp.#{@bc_name}.validation.network", ext_net: extnet)
      end
      if network_proposal["attributes"]["network"]["networks"][ext_net].nil?
        validation_error I18n.t("barclamp.#{@bc_name}.validation.external_network", ext_net: extnet)
      end
    end
  end

  def validate_infoblox(proposal)
    # Validation for grids list
    if proposal["attributes"]["neutron"]["infoblox"]["grids"].empty?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.infoblox_grids")
    end

    dc_id = proposal["attributes"]["neutron"]["infoblox"]["cloud_data_center_id"]
    grids_length = proposal["attributes"]["neutron"]["infoblox"]["grids"].length
    if dc_id.to_i >= grids_length
      validation_error I18n.t("barclamp.#{@bc_name}.validation.infoblox_dc_id",
                              dc_id: dc_id, grids_len: grids_length)
    end
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "neutron-server"
    validate_at_least_n_for_role proposal, "neutron-network", 1

    plugin = proposal["attributes"]["neutron"]["networking_plugin"]

    validate_ml2(proposal) if plugin == "ml2"
    validate_l2pop(proposal)
    validate_dvr(proposal)
    if proposal[:attributes][:neutron][:use_infoblox]
      validate_infoblox(proposal)
    end

    unless proposal["attributes"]["neutron"]["additional_external_networks"].empty?
      validate_external_networks proposal["attributes"]["neutron"]["additional_external_networks"]
    end

    super
  end

  def update_ovs_bridge_attributes(attributes, node)
    needs_save = false
    ovs_bridge_networks = []
    ml2_mechanism_drivers = []
    if attributes["networking_plugin"] == "ml2"
      ml2_type_drivers = attributes["ml2_type_drivers"]
      ml2_mechanism_drivers = attributes["ml2_mechanism_drivers"]
      if ml2_mechanism_drivers.include?("openvswitch")
        # This node needs the ovs packages installed and the service started
        node.crowbar["network"] ||= {}
        unless node.crowbar["network"]["needs_openvswitch"]
          node.crowbar["network"]["needs_openvswitch"] = true
          needs_save = true
        end
        # We need to create ovs bridges for floating and (when vlan type driver
        # is enabled) nova_fixed.  Adjust the network attribute accordingly.
        # We only do that on the node attributes and not the proposal itself as
        # the requirement to have the bridge setup is really node-specifc. (E.g.
        # a tempest node that might get an IP allocated in "nova_floating" won't
        # need the bridges)
        ovs_bridge_networks = ["nova_floating"]
        ovs_bridge_networks.concat attributes["additional_external_networks"]
        if ml2_type_drivers.include?("vlan")
          ovs_bridge_networks << "nova_fixed"
        end
        ovs_bridge_networks.each do |net|
          if node.crowbar["crowbar"]["network"][net]
            unless node.crowbar["crowbar"]["network"][net]["add_ovs_bridge"]
              @logger.info("Forcing add_ovs_bridge to true for the #{net} network on node #{node.name}")
              node.crowbar["crowbar"]["network"][net]["add_ovs_bridge"] = true
              needs_save = true
            end
          end
        end
      end
    end
    # Cleanup the add_ovs_bridge bridge flag on all other networks.
    node.crowbar["crowbar"]["network"].keys.each do |net|
      unless ovs_bridge_networks.include?(net)
        if node.crowbar["crowbar"]["network"][net]["add_ovs_bridge"]
          @logger.info("Forcing add_ovs_bridge to false for the #{net} network on node #{node.name}")
          node.crowbar["crowbar"]["network"][net]["add_ovs_bridge"] = false
          needs_save = true
        end
      end
    end
    if ovs_bridge_networks.empty? && !ml2_mechanism_drivers.include?("openvswitch")
      if node.crowbar["network"] && node.crowbar["network"]["needs_openvswitch"]
        node.crowbar["network"]["needs_openvswitch"] = false
        needs_save = true
      end
    end
    node.save if needs_save
  end

  def enable_neutron_networks(attributes, nodename, net_svc, needs_external = true)
    if needs_external
      net_svc.enable_interface "default", "nova_floating", nodename
      attributes["additional_external_networks"].each do |extnet|
        net_svc.enable_interface "default", extnet, nodename
      end
    end

    if attributes["networking_plugin"] == "ml2"
      ml2_type_drivers = attributes["ml2_type_drivers"]
      if ml2_type_drivers.include?("gre") || ml2_type_drivers.include?("vxlan")
        net_svc.allocate_ip "default", "os_sdn", "host", nodename
      end
      if ml2_type_drivers.include?("vlan")
        net_svc.enable_interface "default", "nova_fixed", nodename
        # reload node as the above enable_interface call might have changed it
        node = NodeObject.find_node_by_name nodename
        # Force "use_vlan" to false in VLAN mode (linuxbridge and ovs). We
        # need to make sure that the network recipe does NOT create the
        # VLAN interfaces (ethX.VLAN)
        if node.crowbar["crowbar"]["network"]["nova_fixed"]["use_vlan"]
          @logger.info("Forcing use_vlan to false for the nova_fixed network on node #{nodename}")
          node.crowbar["crowbar"]["network"]["nova_fixed"]["use_vlan"] = false
          node.save
        end
      end
    elsif attributes["networking_plugin"] == "vmware"
      net_svc.allocate_ip "default", "os_sdn", "host", node
    end
    node = NodeObject.find_node_by_name nodename
    update_ovs_bridge_attributes(attributes, node)
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Neutron apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    net_svc = NetworkService.new @logger
    network_proposal = Proposal.find_by(barclamp: net_svc.bc_name, name: "default")
    if network_proposal["attributes"]["network"]["networks"]["os_sdn"].nil?
      raise I18n.t("barclamp.neutron.deploy.missing_os_sdn_network")
    end

    server_elements, server_nodes, server_ha_enabled = role_expand_elements(role, "neutron-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if server_ha_enabled
    network_elements, network_nodes, network_ha_enabled = role_expand_elements(role, "neutron-network")
    reset_sync_marks_on_clusters_founders(network_elements)
    Openstack::HA.set_controller_role(network_nodes) if network_ha_enabled

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["neutron", "ha", "server", "enabled"], server_ha_enabled, server_elements, vip_networks)
    dirty = prepare_role_for_ha(role, ["neutron", "ha", "network", "enabled"], network_ha_enabled) || dirty
    role.save if dirty

    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(server_elements, vip_networks)

    network_nodes.each do |n|
      enable_neutron_networks(role.default_attributes["neutron"], n, net_svc)
    end
    @logger.debug("Neutron apply_role_pre_chef_call: leaving")
  end
end
