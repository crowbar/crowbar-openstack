# Copyright 2012, Dell Inc. 
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

class CinderService < PacemakerServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "cinder"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "cinder-controller" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true,
          "admin" => false
        },
        "cinder-volume" => {
          "unique" => false,
          "count" => -1,
          "admin" => false
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    deps = ["database", "keystone", "glance", "rabbitmq"]
    deps << "git" if role.default_attributes[@bc_name]["use_gitrepo"]
    deps.each do |dep|
      answer << { "barclamp" => dep, "inst" => role.default_attributes[@bc_name]["#{dep}_instance"] }
    end
    answer
  end

  def create_proposal
    @logger.debug("Cinder create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      controller        = nodes.detect { |n| n.intended_role == "controller"} || nodes.first
      storage           = nodes.detect { |n| n.intended_role == "storage" } || controller
      base["deployment"]["cinder"]["elements"] = {
        "cinder-controller"     => [ controller[:fqdn] ],
        "cinder-volume"         => [ storage[:fqdn] ]
      }
    end

    base["attributes"][@bc_name]["git_instance"] = find_dep_proposal("git", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")

    base["attributes"]["cinder"]["service_password"] = '%012d' % rand(1e12)
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Cinder create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "cinder-controller"
    validate_at_least_n_for_role proposal, "cinder-volume", 1

    if proposal["attributes"][@bc_name]["volume"]["volume_type"] == "raw"
      nodes_without_suitable_drives = proposal["deployment"][@bc_name]["elements"]["cinder-volume"].select do |node_name|
        node = NodeObject.find_node_by_name(node_name)
        node && node.unclaimed_physical_drives.empty? && node.physical_drives.none? { |d, data| node.disk_owner(node.unique_device_for(d)) == 'Cinder' }
      end
      unless nodes_without_suitable_drives.empty?
        validation_error("Nodes #{nodes_without_suitable_drives.to_sentence} for cinder volume role are missing at least one unclaimed disk, required when using raw devices.")
      end
    end

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Cinder apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    controller_elements, controller_nodes, ha_enabled = role_expand_elements(role, "cinder-controller")

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["cinder", "ha", "enabled"], ha_enabled, controller_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    controller_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(controller_elements, vip_networks)

    @logger.debug("Cinder apply_role_pre_chef_call: leaving")
  end

end

