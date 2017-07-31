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

class CeilometerService < OpenstackServiceObject
  def initialize(thelogger = nil)
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
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          }
        },
        "ceilometer-agent-hyperv" => {
          "unique" => false,
          "count" => -1,
          "platform" => {
            "windows" => "/.*/"
          }
        },
        "ceilometer-central" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "ceilometer-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "ceilometer-swift-proxy-middleware" => {
          "unique" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          }
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
    answer
  end

  def create_proposal
    @logger.debug("Ceilometer create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database", true)
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    agent_nodes = NodeObject.find("roles:nova-compute-kvm") +
      NodeObject.find("roles:nova-compute-qemu") +
      NodeObject.find("roles:nova-compute-vmware") +
      NodeObject.find("roles:nova-compute-xen")

    # hyperv_agent_nodes = NodeObject.find("roles:nova-compute-hyperv")

    nodes       = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    server_nodes = nodes.select { |n| n.intended_role == "controller" }
    server_nodes = [nodes.first] if server_nodes.empty?

    swift_proxy_nodes = NodeObject.find("roles:swift-proxy")

    # (2017-01-30): Hyper-V is hidden for now
    # "ceilometer-agent-hyperv" => hyperv_agent_nodes.map { |x| x.name },
    base["deployment"]["ceilometer"]["elements"] = {
        "ceilometer-agent" => agent_nodes.map { |x| x.name },
        "ceilometer-central" => [server_nodes.first.name],
        "ceilometer-server" => [server_nodes.first.name],
        "ceilometer-swift-proxy-middleware" => swift_proxy_nodes.map { |x| x.name }
    } unless agent_nodes.nil? or server_nodes.nil?

    base["attributes"]["ceilometer"]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name][:metering_secret] = random_password

    @logger.debug("Ceilometer create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "ceilometer-central"
    validate_one_for_role proposal, "ceilometer-server"

    validate_minimum_three_nodes_in_cluster(proposal)

    # unless (proposal["deployment"]["ceilometer"]["elements"]["ceilometer-agent-hyperv"] || []).empty? || hyperv_available?
    #   validation_error I18n.t("barclamp.#{@bc_name}.validation.hyper_v_support")
    # end

    swift_proxy_nodes = NodeObject.find("roles:swift-proxy").map { |x| x.name }
    if proposal["deployment"]["ceilometer"]["elements"]["ceilometer-swift-proxy-middleware"]
      proposal["deployment"]["ceilometer"]["elements"]["ceilometer-swift-proxy-middleware"].each do |n|
        unless swift_proxy_nodes.include? n
          validation_error I18n.t("barclamp.#{@bc_name}.validation.swift_proxy")
        end
      end
    end
    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Ceilometer apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    unless hyperv_available?
      role.override_attributes["ceilometer"]["elements"]["ceilometer-hyperv-agent"] = []
    end

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "ceilometer-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

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

    use_mongodb = role.default_attributes[@bc_name]["use_mongodb"]
    mongodb_ha(server_nodes, role) if ha_enabled && use_mongodb

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(server_elements, vip_networks)

    central_elements, central_nodes, central_ha_enabled = \
      role_expand_elements(role, "ceilometer-central")
    reset_sync_marks_on_clusters_founders(central_elements)
    Openstack::HA.set_controller_role(central_nodes) if central_ha_enabled

    role.save if prepare_role_for_ha(role,\
                                     ["ceilometer", "ha", "central", "enabled"],\
                                     central_ha_enabled)

    @logger.debug("Ceilometer apply_role_pre_chef_call: leaving")
  end

  def mongodb_ha(new_members, role)
    # enforce that mongodb is only installed on an odd number of nodes
    # so we don't get problems when they try to vote for a replica set
    # primary node
    new_members.pop if new_members.length % 2 == 0

    # this is just the node we use to communicate to mongodb and
    # configure the replica set
    controller = new_members.sort.first

    logger.debug("Configuring a MongoDB Replica Set with "\
      "the following nodes: #{new_members.join(", ")}")

    # make sure only the current replica set new_members have the replica
    # set attributes enabled
    old_members = NodeObject.find("ceilometer_ha_mongodb_replica_set_member:true AND ceilometer_config_environment:#{role.name}")
    old_members.each do |old_member|
      next if new_members.include?(old_member.name)
      old_member[:ceilometer][:ha][:mongodb][:replica_set][:member] = false
      old_member[:ceilometer][:ha][:mongodb][:replica_set][:controller] = false
      old_member.save
    end

    new_members.each do |new_member|
      dirty = false

      node = NodeObject.find_node_by_name(new_member)
      node[:ceilometer] ||= {ha: {mongodb: {replica_set: {}}}}

      # explicit check for true; otherwise it doesn't work
      unless node[:ceilometer][:ha][:mongodb][:replica_set][:member] == true
        node[:ceilometer][:ha][:mongodb][:replica_set][:member] = true
        dirty = true
      end

      is_controller = (new_member == controller)
      unless node[:ceilometer][:ha][:mongodb][:replica_set][:controller] == is_controller
        node[:ceilometer][:ha][:mongodb][:replica_set][:controller] = is_controller
        dirty = true
      end

      node.save if dirty
    end
  end

  private

  # If the ceilometer-server role has a cluster assigned, we want to
  # make sure that the cluster contains at least three nodes. MongoDB HA
  # requires it; otherwise the Replica Set wouldn't be able to elect a
  # primary.
  def validate_minimum_three_nodes_in_cluster(proposal)
    servers = proposal["deployment"][@bc_name]["elements"]["ceilometer-server"]
    use_mongodb = proposal["attributes"][@bc_name]["use_mongodb"]

    if use_mongodb && servers.length == 1 && is_cluster?(servers[0])
      nodes, failures = expand_nodes_for_all servers

      @logger.debug("validate_minimum_three_nodes_in_cluster: skipping "\
        "items that we failed to expand: #{failures.join(", ")}"
        ) unless failures.nil? || failures.empty?

      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.nodes_count",
        nodes_count: nodes.count
      ) if nodes.length < 3
    end
  end

  def hyperv_available?
    return File.exist?("/opt/dell/chef/cookbooks/hyperv")
  end
end
