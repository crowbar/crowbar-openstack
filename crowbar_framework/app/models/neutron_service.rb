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

class NeutronService < PacemakerServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "neutron"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "neutron-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "12.0",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "neutron-l3" => {
          "unique" => false,
          "count" => 1,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "12.0",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    if role.default_attributes["neutron"]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes["neutron"]["git_instance"] }
    end
    answer << { "barclamp" => "database", "inst" => role.default_attributes["neutron"]["database_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["neutron"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["neutron"]["keystone_instance"] }
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"][@bc_name]["git_instance"] = find_dep_proposal("git", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    controller_nodes = nodes.select { |n| n.intended_role == "controller" }
    controller_node = controller_nodes.first
    controller_node ||= nodes.first

    network_nodes = nodes.select { |n| n.intended_role == "network" }
    network_nodes = [ controller_node ] if network_nodes.empty?

    base["deployment"]["neutron"]["elements"] = {
        "neutron-server" => [ controller_node[:fqdn] ],
        "neutron-l3" => network_nodes.map { |x| x[:fqdn] }
    } unless nodes.nil? or nodes.length ==0

    base["attributes"]["neutron"]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "neutron-server"
    validate_at_least_n_for_role proposal, "neutron-l3", 1

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    plugin = proposal["attributes"]["neutron"]["networking_plugin"]
    ml2_mechanism_drivers = proposal["attributes"]["neutron"]["ml2_mechanism_drivers"]
    ml2_type_drivers = proposal["attributes"]["neutron"]["ml2_type_drivers"]
    ml2_type_drivers_default_provider_network = proposal["attributes"]["neutron"]["ml2_type_drivers_default_provider_network"]
    ml2_type_drivers_default_tenant_network = proposal["attributes"]["neutron"]["ml2_type_drivers_default_tenant_network"]

    # at least one ml2 type driver must be selected for ml2 as core plugin
    if plugin == 'ml2' && ml2_type_drivers.length == 0
      validation_error("At least one ml2 type driver must be selected")
    end

    # at least one ml2 mech driver must be selected for ml2 as core plugin
    if plugin == 'ml2' && ml2_mechanism_drivers.length == 0
      validation_error("At least one ml2 mechanism driver must be selected")
    end

    # default provider network ml2 type driver must be a driver from the selected ml2 type drivers
    # TODO(toabctl): select the ml2_type_driver automatically if used as default? Or directly check in the ui via js?
    unless ml2_type_drivers.include?(ml2_type_drivers_default_provider_network)
      validation_error("The default provider network type driver \"#{ml2_type_drivers_default_provider_network}\" is not a selected ml2 type driver")
    end

    # default tenant network ml2 type driver must be a driver from the selected ml2 type drivers
    # TODO(toabctl): select the ml2_type_driver automatically if used as default? Or directly check in the ui via js?
    unless ml2_type_drivers.include?(ml2_type_drivers_default_tenant_network)
      validation_error("The default tenant network type driver \"#{ml2_type_drivers_default_tenant_network}\" is not a selected ml2 type driver")
    end

    # linuxbridge and cisco_nexus mech drivers need vlan type driver
    # TODO(toabctl): select vlan type driver automatically if linuxbridge or cisco were selected!?
    %w(linuxbridge cisco_nexus).each do |drv|
      if ml2_mechanism_drivers.include? drv and not ml2_type_drivers.include? 'vlan'
        validation_error("The mechanism driver \"#{drv}\" needs the type driver \"vlan\"")
      end
    end

    # cisco_nexus mech driver needs also openvswitch mech driver
    # TODO(toabctl): select openvswitch automatically if cisco_nexus was selected!?
    if ml2_mechanism_drivers.include? "cisco_nexus" and not ml2_mechanism_drivers.include? "openvswitch"
      validation_error("The 'cisco_nexus' mechanism driver needs also the 'openvswitch' mechanism driver")
    end

    # for now, openvswitch and linuxbrige can't be used in parallel
    if ml2_mechanism_drivers.include? "openvswitch" and ml2_mechanism_drivers.include? "linuxbridge"
      validation_error("The 'openvswitch' and 'linuxbridge' mechanism drivers can't be used in parallel. Only select one of them")
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Neutron apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    net_svc = NetworkService.new @logger
    network_proposal = ProposalObject.find_proposal(net_svc.bc_name, "default")
    if network_proposal["attributes"]["network"]["networks"]["os_sdn"].nil?
      raise I18n.t("barclamp.neutron.deploy.missing_os_sdn_network")
    end

    server_elements, server_nodes, server_ha_enabled = role_expand_elements(role, "neutron-server")
    l3_elements, l3_nodes, l3_ha_enabled = role_expand_elements(role, "neutron-l3")

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["neutron", "ha", "server", "enabled"], server_ha_enabled, server_elements, vip_networks)
    dirty = prepare_role_for_ha(role, ["neutron", "ha", "l3", "enabled"], l3_ha_enabled) || dirty
    role.save if dirty

    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(server_elements, vip_networks)

    l3_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host",n
      # TODO(toabctl): The same code is in the nova barclamp. Should be extracted and reused!
      #                (see crowbar_framework/app/models/nova_service.rb)
      if role.default_attributes["neutron"]["networking_plugin"] == "ml2"
        if role.default_attributes["neutron"]["ml2_type_drivers"].include?("gre")
          net_svc.allocate_ip "default","os_sdn","host", n
        end
        if role.default_attributes["neutron"]["ml2_type_drivers"].include?("vlan")
          net_svc.enable_interface "default", "nova_fixed", n
          # Force "use_vlan" to false in VLAN mode (linuxbridge and ovs). We
          # need to make sure that the network recipe does NOT create the
          # VLAN interfaces (ethX.VLAN)
          node = NodeObject.find_node_by_name n
          if node.crowbar["crowbar"]["network"]["nova_fixed"]["use_vlan"]
            @logger.info("Forcing use_vlan to false for the nova_fixed network on node #{n}")
            node.crowbar["crowbar"]["network"]["nova_fixed"]["use_vlan"] = false
            node.save
          end
        end
      end
    end
    @logger.debug("Neutron apply_role_pre_chef_call: leaving")
  end

end
