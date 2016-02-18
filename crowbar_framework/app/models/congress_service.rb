#
# Copyright 2015, SUSE LINUX GmbH
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

class CongressService < PacemakerServiceObject
  def initialize(thelogger)
    @bc_name = "congress"
    @logger = thelogger
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
  def role_constraints
    {
      "congress-server" => {
        "unique" => false,
        "count" => 1,
        "cluster" => true,
        "admin" => false,
        "exclude_platform" => {
          "suse" => "< 12.1",
          "windows" => "/.*/"
        }
      },
    }
  end
end

  def proposal_dependencies(role)
    answer = []
    # NOTE(toabctl): nova, cinder, glance and neutron are just needed
    # for the generic driver. So this could be optional depending on the used
    # driver
    deps = ["database", "keystone", "rabbitmq"]
    # ["nova", "cinder", "glance", "neutron"]
    deps.each do |dep|
      answer << {
        "barclamp" => dep,
        "inst" => role.default_attributes[@bc_name]["#{dep}_instance"]
      }
    end
    answer
  end

  def create_proposal
    @logger.debug("Congress create_proposal: entering")
    base = super

    nodes = NodeObject.all
    # Congress shall use controller for launching the server
    controllers = select_nodes_for_role(
      nodes, "congress-server", "controller") || []

    base["deployment"][@bc_name]["elements"] = {
      "congress-server" => controllers.empty? 
    }

    base["attributes"][@bc_name]["database_instance"] =
      find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] =
      find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] =
      find_dep_proposal("keystone")
    base["attributes"][@bc_name]["nova_instance"] =
      find_dep_proposal("nova")
    base["attributes"][@bc_name]["cinder_instance"] =
      find_dep_proposal("cinder")
    base["attributes"][@bc_name]["glance_instance"] =
      find_dep_proposal("glance")
    base["attributes"][@bc_name]["neutron_instance"] =
      find_dep_proposal("neutron")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Congress create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "congress-server"

    super
  end

  def apply_role_pre_chef_call(_old_role, role, all_nodes)
    @logger.debug("Congress apply_role_pre_chef_call: "\
                  "entering #{all_nodes.inspect}")

    return if all_nodes.empty?

    controller_elements,
    controller_nodes,
    ha_enabled = role_expand_elements(role, "congress-server")
    vip_networks = ["admin", "public"]

    dirty = prepare_role_for_ha_with_haproxy(
      role, ["congress", "ha", "enabled"],
      ha_enabled, controller_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    controller_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(
      controller_elements, vip_networks)

    # Make sure the bind hosts are in the admin network
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n

      admin_address = node.get_network_by_type("admin")["address"]
      node.crowbar[:congress] = {} if node.crowbar[:congress].nil?
      node.crowbar[:congress][:api_bind_host] = admin_address

      node.save
    end
    @logger.debug("Congress apply_role_pre_chef_call: leaving")
  end
end
