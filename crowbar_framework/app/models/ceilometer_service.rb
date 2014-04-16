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

class CeilometerService < PacemakerServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "ceilometer"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "ceilometer-agent" => {
          "unique" => false,
          "count" => -1
        },
        "ceilometer-cagent" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true
        },
        "ceilometer-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true
        },
        "ceilometer-swift-proxy-middleware" => {
          "unique" => false,
          "count" => -1
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["ceilometer"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["ceilometer"]["keystone_instance"] }
    unless role.default_attributes["ceilometer"]["use_mongodb"]
      answer << { "barclamp" => "database", "inst" => role.default_attributes["ceilometer"]["database_instance"] }
    end
    if role.default_attributes["ceilometer"]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes["ceilometer"]["git_instance"] }
    end
    answer
  end

  def create_proposal
    @logger.debug("Ceilometer create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["git_instance"] = find_dep_proposal("git", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database", true)
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    agent_nodes = NodeObject.find("roles:nova-multi-compute-kvm") +
      NodeObject.find("roles:nova-multi-compute-qemu") +
      NodeObject.find("roles:nova-multi-compute-vmware") +
      NodeObject.find("roles:nova-multi-compute-xen")

    nodes       = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    server_nodes = nodes.select { |n| n.intended_role == "controller" }
    server_nodes = [ nodes.first ] if server_nodes.empty?

    swift_proxy_nodes = NodeObject.find("roles:swift-proxy")

    base["deployment"]["ceilometer"]["elements"] = {
        "ceilometer-agent" =>  agent_nodes.map { |x| x.name },
        "ceilometer-cagent" =>  server_nodes.map { |x| x.name },
        "ceilometer-server" =>  server_nodes.map { |x| x.name },
        "ceilometer-swift-proxy-middleware" =>  swift_proxy_nodes.map { |x| x.name }
    } unless agent_nodes.nil? or server_nodes.nil?

    base["attributes"]["ceilometer"]["keystone_service_password"] = '%012d' % rand(1e12)
    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name][:metering_secret] = random_password

    @logger.debug("Ceilometer create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "ceilometer-cagent"
    validate_one_for_role proposal, "ceilometer-server"

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    swift_proxy_nodes = NodeObject.find("roles:swift-proxy").map { |x| x.name }
    proposal["deployment"]["ceilometer"]["elements"]["ceilometer-swift-proxy-middleware"].each do |n|
      unless swift_proxy_nodes.include? n
        validation_error("Nodes with the ceilometer-swift-proxy-middleware role must also have the swift-proxy role.")
      end
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Ceilometer apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "ceilometer-server")

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["ceilometer", "ha", "server", "enabled"], ha_enabled, server_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(server_elements, vip_networks)

    central_elements, central_nodes, central_ha_enabled = role_expand_elements(role, "ceilometer-cagent")

    role.save if prepare_role_for_ha(role, ["ceilometer", "ha", "central", "enabled"], central_ha_enabled)

    @logger.debug("Ceilometer apply_role_pre_chef_call: leaving")
  end

end
