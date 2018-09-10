#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
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

class MagnumService < OpenstackServiceObject
  def initialize(thelogger = nil)
    @bc_name = "magnum"
    @logger = thelogger
  end

  # Turn off multi proposal support till it really works and people ask for it
  def self.allow_multiple_proposals?
    false
  end

  def proposal_dependencies(role)
    answer = []
    deps = ["database", "rabbitmq", "keystone", "nova", "glance", "neutron", "heat"]
    deps.each do |dep|
      answer << {
        "barclamp" => dep,
        "inst" => role.default_attributes[@bc_name]["#{dep}_instance"]
      }
    end
    answer
  end

  class << self
    def role_constraints
      {
        "magnum-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def create_proposal
    @logger.debug("Magnum create_proposal: entering")
    base = super

    nodes = NodeObject.all
    controllers = select_nodes_for_role(
      nodes, "magnum-server", "controller") || []

    base["deployment"][@bc_name]["elements"] = {
      "magnum-server" => controllers.empty? ? [] : [controllers.first.name]
    }

    base["attributes"][@bc_name]["database_instance"] =
      find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] =
      find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] =
      find_dep_proposal("keystone")
    base["attributes"][@bc_name]["nova_instance"] =
      find_dep_proposal("nova")
    base["attributes"][@bc_name]["glance_instance"] =
      find_dep_proposal("glance")
    base["attributes"][@bc_name]["neutron_instance"] =
      find_dep_proposal("neutron")
    base["attributes"][@bc_name]["heat_instance"] =
      find_dep_proposal("heat")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name]["memcache_secret_key"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name][:trustee][:domain_admin_password] = random_password

    @logger.debug("Magnum create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "magnum-server"
    if proposal["attributes"][@bc_name]["cert"]["cert_manager_type"] == "barbican"
      # Check if barbican barclamp is applied and active
      barbican_role = NodeObject.find("roles:barbican-controller")
      if barbican_role.empty?
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.barbican.barbican_not_deployed"
        )
      end
    end
    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Magnum apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "magnum-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = prepare_role_for_ha_with_haproxy(role, ["magnum", "ha", "enabled"],
                                             ha_enabled, server_elements, vip_networks)
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

    @logger.debug("Magnum apply_role_pre_chef_call: leaving")
  end
end
