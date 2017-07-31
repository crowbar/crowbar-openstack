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

class HeatService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "heat"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "heat-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["heat"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["heat"]["keystone_instance"] }
    answer << { "barclamp" => "database", "inst" => role.default_attributes["heat"]["database_instance"] }
    answer
  end

  def create_proposal
    @logger.debug("Heat create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["heat"]["elements"] = {
        "heat-server" =>  [controller.name]
      }
    end

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name]["stack_domain_admin_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password
    encryption_key = random_password
    while encryption_key.length < 32 do
      encryption_key += random_password
    end
    base["attributes"][@bc_name][:auth_encryption_key] = encryption_key

    @logger.debug("Heat create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "heat-server"

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Heat apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    vip_networks = ["admin", "public"]

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "heat-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    role.save if prepare_role_for_ha_with_haproxy(role, ["heat", "ha", "enabled"], ha_enabled, server_elements, vip_networks)

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks(server_elements, vip_networks)

    @logger.debug("Heat apply_role_pre_chef_call: leaving")
  end
end
