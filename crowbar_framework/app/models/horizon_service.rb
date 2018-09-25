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

class HorizonService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "horizon"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "horizon-server" => {
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
    answer << { "barclamp" => "database", "inst" => role.default_attributes["horizon"]["database_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["horizon"]["keystone_instance"] }
    answer
  end

  def create_proposal
    @logger.debug("Horizon create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["horizon"]["elements"] = {
        "horizon-server" => [controller[:fqdn]]
      }
    end

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name]["secret_key"] = random_password

    @logger.debug("Horizon create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "horizon-server"

    if proposal["attributes"][@bc_name]["multi_domain_support"]
      ks_svc = KeystoneService.new @logger
      keystone = Proposal.find_by(barclamp: ks_svc.bc_name,
                                  name: proposal["attributes"]["horizon"]["keystone_instance"])
      # Using domains requires API Version 3 or newer
      if keystone["attributes"][ks_svc.bc_name]["api"]["version"].to_f < 3.0
        validation_error I18n.t("barclamp.#{@bc_name}.validation.enable_keystone")
      end
    end

    horizon_timeout = proposal["attributes"]["horizon"]["session_timeout"]
    keystone_proposal = Proposal.where(barclamp: "keystone", name: "default").first
    unless keystone_proposal.nil?
      keystone_timeout = keystone_proposal["attributes"]["keystone"]["token_expiration"]

      # keystone_timeout is in seconds and horizon_timeout is in minutes
      if horizon_timeout * 60 > keystone_timeout
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.timeout",
          horizon_timeout: horizon_timeout,
          keystone_timeout: (keystone_timeout / 60)
        )
      end
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Horizon apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "horizon-server")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["horizon", "ha", "enabled"], ha_enabled, server_elements, vip_networks)
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

    # Make sure the nodes have a link to the dashboard on them.
    if role.default_attributes["horizon"]["apache"]["ssl"]
      protocol = "https"
    else
      protocol = "http"
    end

    if ha_enabled
      # This assumes that there can only be one cluster assigned to the
      # horizon-server role (otherwise, we'd need to check to which
      # cluster each node belongs to create the link).
      # Good news, the assumption is correct :-)
      hostname = nil
      server_elements.each do |element|
        if is_cluster? element
          hostname = PacemakerServiceObject.cluster_vhostname_from_element(element)
          break
        end
      end

      raise "Cannot find hostname for VIP of cluster" if hostname.nil?

      public_server_ip = PacemakerServiceObject.vhostname_to_vip(hostname, "public")
      admin_server_ip = PacemakerServiceObject.vhostname_to_vip(hostname, "admin")
    end

    server_nodes.each do |n|
      node = NodeObject.find_node_by_name(n)
      node.crowbar["crowbar"] ||= {}
      node.crowbar["crowbar"]["links"] ||= {}

      unless ha_enabled
        public_server_ip = node.get_network_by_type("public")["address"]
        admin_server_ip = node.get_network_by_type("admin")["address"]
      end

      node.crowbar["crowbar"]["links"].delete("Nova Dashboard (public)")
      node.crowbar["crowbar"]["links"]["OpenStack Dashboard (public)"] = "#{protocol}://#{public_server_ip}/"

      node.crowbar["crowbar"]["links"].delete("Nova Dashboard (admin)")
      node.crowbar["crowbar"]["links"]["OpenStack Dashboard (admin)"] = "#{protocol}://#{admin_server_ip}/"

      node.save
    end

    @logger.debug("Horizon apply_role_pre_chef_call: leaving")
  end
end
