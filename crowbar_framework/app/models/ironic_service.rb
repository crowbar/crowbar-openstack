# frozen_string_literal: true
#
# Copyright 2016, SUSE
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

class IronicService < ServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "ironic"
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "ironic-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => false
        }
      }
    end
  end

  def proposal_dependencies(role)
    ironic_attributes = role.default_attributes["ironic"]
    answer = []
    answer << { "barclamp" => "rabbitmq", "inst" => ironic_attributes["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => ironic_attributes["keystone_instance"] }
    answer << { "barclamp" => "glance", "inst" => ironic_attributes["glance_instance"] }
    answer << { "barclamp" => "database", "inst" => ironic_attributes["database_instance"] }
    answer << { "barclamp" => "neutron", "inst" => ironic_attributes["neutron_instance"] }
    answer
  end

  def create_proposal
    @logger.debug("Ironic create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")
    base["attributes"][@bc_name]["neutron_instance"] = find_dep_proposal("neutron")

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? || n.admin? }

    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["ironic"]["elements"] = {
        "ironic-server" => [controller.name]
      }
    end

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name]["memcache_secret_key"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Ironic create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "ironic-server"

    net_svc = NetworkService.new @logger
    network_proposal = Proposal.find_by(barclamp: net_svc.bc_name, name: "default")
    if network_proposal["attributes"]["network"]["networks"]["ironic"].nil?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.ironic_network")
    end

    if proposal["attributes"][@bc_name]["enabled_drivers"].empty?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.no_drivers")
    end

    if proposal["attributes"][@bc_name]["enabled_drivers"].any? { |d| d.include?("ssh") }
      validation_error I18n.t("barclamp.#{@bc_name}.validation.wrong_drivers")
    end

    # additional soft dependencies for agent_* drivers
    if proposal["attributes"][@bc_name]["enabled_drivers"].any? { |d| d.start_with?("agent_") }
      swift_svc = SwiftService.new @logger
      swift_proposal = Proposal.find_by(barclamp: swift_svc.bc_name, name: "default")
      if swift_proposal
        unless swift_proposal["attributes"][swift_svc.bc_name]["middlewares"]["tempurl"]["enabled"]
          validation_error I18n.t("barclamp.#{@bc_name}.validation.swift_tempurl_enabled")
        end
      else
        validation_error I18n.t("barclamp.#{@bc_name}.validation.swift_proposal")
      end

      glance_svc = GlanceService.new @logger
      glance_proposal = Proposal.find_by(barclamp: glance_svc.bc_name, name: "default")
      unless glance_proposal["attributes"][glance_svc.bc_name]["default_store"] == "swift"
        validation_error I18n.t("barclamp.#{@bc_name}.validation.glance_swift_default_store")
      end
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Ironic apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    neutron = Proposal.find_by(barclamp: "neutron",
                               name: role.default_attributes[@bc_name]["neutron_instance"])

    neutron_service = NeutronService.new @logger
    net_svc = NetworkService.new @logger
    all_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
      net_svc.allocate_ip "default", "ironic", "admin", n

      node = NodeObject.find_node_by_name n
      neutron_service.update_ovs_bridge_attributes(neutron["attributes"]["neutron"], node)
    end

    @logger.debug("Ironic apply_role_pre_chef_call: leaving")
  end
end
