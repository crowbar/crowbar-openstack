#
# Copyright 2017, SUSE LINUX GmbH
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

class AodhService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "aodh"
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "aodh-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    deps = ["database", "rabbitmq", "keystone", "ceilometer"]
    deps.each do |dep|
      answer << {
        "barclamp" => dep,
        "inst" => role.default_attributes[@bc_name]["#{dep}_instance"]
      }
    end
    answer
  end

  def create_proposal
    @logger.debug("Aodh create_proposal: entering")
    base = super

    nodes = NodeObject.all
    controllers = select_nodes_for_role(nodes, "aodh-server", "controller") || []

    base["deployment"][@bc_name]["elements"] = {
      "aodh-server" => controllers.empty? ? [] : [controllers.first.name]
    }

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["ceilometer_instance"] = find_dep_proposal("ceilometer")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name]["memcache_secret_key"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Aodh create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "aodh-server"

    validate_at_least_n_for_role proposal, "aodh-server", 1

    alarm_eval_interval = proposal["attributes"][@bc_name]["evaluation_interval"]

    ceilometer_proposal = Proposal.where(barclamp: "ceilometer", name: "default").first
    ["cpu_interval", "disk_interval", "network_interval", "meters_interval"].each do |i|
      if alarm_eval_interval < ceilometer_proposal["attributes"]["ceilometer"][i]
        validation_error I18n.t("barclamp.#{@bc_name}.validation.evaluation_interval")
        break
      end
    end
    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Aodh apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "aodh-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    role.save if prepare_role_for_ha_with_haproxy(role, ["aodh", "ha", "server", "enabled"],
                                                  ha_enabled, server_elements, vip_networks)

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(server_elements, vip_networks)

    @logger.debug("Aodh apply_role_pre_chef_call: leaving")
  end
end
