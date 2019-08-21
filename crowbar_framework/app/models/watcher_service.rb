#
# Copyright 2019, SUSE LINUX GmbH
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

class WatcherService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "watcher"
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "watcher-server" => {
          "unique" => false,
          "cluster" => true,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "database", "inst" => role.default_attributes["watcher"]["database_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["watcher"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["watcher"]["keystone_instance"] }
    answer
  end

  def create_proposal
    @logger.debug("Watcher create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? || n.admin? }
    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["watcher"]["elements"] = {
        "watcher-server" => [controller[:fqdn]]
      }
    end

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    base["attributes"]["watcher"]["service_password"] = random_password
    base["attributes"]["watcher"]["memcache_secret_key"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Watcher create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Watcher apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # Role can be assigned to clusters, so we need to expand the elements
    # to get the actual list of nodes.
    server_elements, server_nodes, has_expanded = role_expand_elements(role, "watcher-server")
    reset_sync_marks_on_clusters_founders(server_elements)

    # If watcher_elements != watcher_nodes, has_expanded will be true, which
    # currently means we want to use HA.
    ha_enabled = has_expanded

    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    # FIXME: this deserves a comment
    vip_networks =
      if role.default_attributes["watcher"]["api"]["bind_open_address"]
        ["admin", "public"]
      else
        ["admin"]
      end

    # Mark HA as enabled and initialize HA and networks in the role's pacemaker attribute
    prepare_role_for_ha_with_haproxy(role, ["watcher", "ha", "enabled"],
      ha_enabled, server_elements, vip_networks) && role.save

    if role.default_attributes["watcher"]["api"]["bind_open_address"]
      net_svc = NetworkService.new @logger
      server_nodes.each do |n|
        net_svc.allocate_ip "default", "public", "host", n
      end
    end

    # Setup virtual IPs for the clusters
    allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(server_elements, vip_networks)

    @logger.debug("Watcher apply_role_pre_chef_call: leaving")
  end
end
