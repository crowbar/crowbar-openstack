#
# Copyright 2016, SUSE LINUX GmbH
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

class MonascaService < PacemakerServiceObject
  def initialize(thelogger)
    @bc_name = "monasca"
    @logger = thelogger
  end

  class << self
    # Turn off multi proposal support till it really works and people ask for it.
    def self.allow_multiple_proposals?
      false
    end

    def role_constraints
      {
        "monasca-agent" => {
          "unique" => false,
          "admin" => true,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        },
        "monasca-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    deps = ["database", "keystone"]
    deps.each do |dep|
      answer << {
        "barclamp" => dep,
        "inst" => role.default_attributes[@bc_name]["#{dep}_instance"]
      }
    end
    answer
  end

  def create_proposal
    @logger.debug("Monasca create_proposal: entering")
    base = super

    nodes = NodeObject.all
    # FIXME: Putting the monasca backend services on the controller is
    # temporary to allow for development right now. We will eventually want the
    # commented line for server_roles, i.e. have a dedicated Monitoring node
    # role in Crowbar. Adding that role will require changes to:
    #
    #  * https://github.com/crowbar/crowbar-core/blob/master/crowbar_framework/app/helpers/nodes_helper.rb#L366
    #  * https://github.com/crowbar/crowbar-core/blob/master/bin/crowbar_machines#L362
    #  * https://github.com/crowbar/crowbar-core/blob/master/crowbar_framework/config/locales/crowbar/en.yml
    #
    # at the very least.
    server_nodes = nodes.select { |n| n.intended_role == "controller" }
    ### server_nodes = nodes.select { |n| n.intended_role == "monitoring" }

    server_nodes = [nodes.first] if server_nodes.empty?

    # TODO: do we really want to have the agent on all nodes by
    # default?
    agent_nodes = nodes

    base["deployment"][@bc_name]["elements"]["monasca-agent"] = agent_nodes
    unless server_nodes.nil?
      base["deployment"][@bc_name]["elements"] = {
        "monasca-server" => [server_nodes.first.name]
      }
    end

    base["attributes"][@bc_name]["database_instance"] =
      find_dep_proposal("database")
    base["attributes"][@bc_name]["keystone_instance"] =
      find_dep_proposal("keystone")
    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Monasca create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "monasca-server"

    super
  end

  def apply_role_pre_chef_call(_old_role, role, all_nodes)
    @logger.debug("Monasca apply_role_pre_chef_call: "\
                  "entering #{all_nodes.inspect}")

    server_elements,
    server_nodes,
    ha_enabled = role_expand_elements(role, "monasca-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = prepare_role_for_ha_with_haproxy(
      role, ["monasca", "ha", "enabled"],
      ha_enabled, server_elements, vip_networks
    )
    role.save if dirty

    unless all_nodes.empty? || server_elements.empty?
      net_svc = NetworkService.new @logger
      # All nodes must have a public IP, even if part of a cluster; otherwise
      # the VIP can't be moved to the nodes
      server_nodes.each do |node|
        net_svc.allocate_ip "default", "public", "host", node
      end
      allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(server_elements, vip_networks)
    end

    @logger.debug("Monasca apply_role_pre_chef_call: leaving")
  end
end
