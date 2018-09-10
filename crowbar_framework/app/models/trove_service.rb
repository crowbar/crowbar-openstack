#
# Copyright 2014, SUSE LINUX Products GmbH
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

class TroveService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "trove"
  end

  class << self
    def role_constraints
      {
        "trove" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def create_proposal
    @logger.debug("Trove create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["nova_instance"] = find_dep_proposal("nova")
    base["attributes"][@bc_name]["cinder_instance"] = find_dep_proposal("cinder")
    base["attributes"][@bc_name]["swift_instance"] = find_dep_proposal("swift", true)
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["db"]["password"] = random_password
    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name]["memcache_secret_key"] = random_password

    # assign a default node to the trove-server role
    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["trove"]["elements"] = {
        "trove-server" => [controller[:fqdn]]
      }
    end

    @logger.debug("Trove create_proposal: exiting")
    base
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes[@bc_name]["keystone_instance"] }
    answer << { "barclamp" => "nova", "inst" => role.default_attributes[@bc_name]["nova_instance"] }
    answer << { "barclamp" => "cinder", "inst" => role.default_attributes[@bc_name]["cinder_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes[@bc_name]["rabbitmq_instance"] }
    if role.default_attributes[@bc_name]["volume_support"]
      answer << { "barclamp" => "swift", "inst" => role.default_attributes[@bc_name]["swift_instance"] }
    end

    answer
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "trove-server"

    rabbitmq_proposal = Proposal.find_by(
      barclamp: "rabbitmq",
      name: proposal["attributes"][@bc_name]["rabbitmq_instance"])

    unless rabbitmq_proposal && rabbitmq_proposal["attributes"]["rabbitmq"]["trove"]["enabled"]
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.rabbitmq_enabled")
    end
    super
  end

  def apply_role_pre_chef_call(old_role, role, all_new_nodes)
    @logger.debug("Trove apply_role_pre_chef_call: entering #{all_new_nodes.inspect}")

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "trove-server")
    # FIXME: uncomment commented out code when enabling HA
    # reset_sync_marks_on_clusters_founders(server_elements)
    # Openstack::HA.set_controller_role(server_nodes) if ha_enabled
    #
    # vip_networks = ["admin", "public"]
    #
    # dirty = prepare_role_for_ha_with_haproxy(role, ["trove", "ha", "enabled"],
    #                                          ha_enabled, server_elements,
    #                                          vip_networks)
    # role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |node|
      net_svc.allocate_ip "default", "public", "host", node
    end

    # allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(server_elements, vip_networks)

    @logger.debug("Trove apply_role_pre_chef_call: leaving")
  end
end
