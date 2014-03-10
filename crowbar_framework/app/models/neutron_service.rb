# Copyright 2011, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class NeutronService < ServiceObject

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
          "count" => 1
        },
        "neutron-l3" => {
          "unique" => false,
          "count" => -1,
          "admin" => false
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

    base["attributes"]["neutron"]["service_password"] = '%012d' % rand(1e12)

    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "neutron-server"
    validate_at_least_n_for_role proposal, "neutron-l3", 1

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    if proposal["attributes"]["neutron"]["networking_plugin"] == "linuxbridge" and
        proposal["attributes"]["neutron"]["networking_mode"] != "vlan"
        validation_error("The \"linuxbridge\" plugin only supports the mode: \"vlan\"")
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

    tnodes = role.override_attributes["neutron"]["elements"]["neutron-server"]
    unless tnodes.nil? or tnodes.empty?
      tnodes.each do |n|
        net_svc.allocate_ip "default", "public", "host", n
      end
    end

    tnodes = role.override_attributes["neutron"]["elements"]["neutron-l3"]
    unless tnodes.nil? or tnodes.empty?
      tnodes.each do |n|
        net_svc.allocate_ip "default", "public", "host",n
        if role.default_attributes["neutron"]["networking_mode"] == "gre"
          net_svc.allocate_ip "default","os_sdn","host", n
        else
          net_svc.enable_interface "default", "nova_fixed", n
          if role.default_attributes["neutron"]["networking_mode"] == "vlan"
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
    end
    @logger.debug("Neutron apply_role_pre_chef_call: leaving")
  end

end
