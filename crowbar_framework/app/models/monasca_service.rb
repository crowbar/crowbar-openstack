#
# Copyright 2016, SUSE LINUX GmbH
# Copyright 2017 FUJITSU LIMITED
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

class MonascaService < OpenstackServiceObject
  def initialize(thelogger = nil)
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
          "admin" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        },
        "monasca-log-agent" => {
          "unique" => false,
          "admin" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        },
        "monasca-server" => {
          "unique" => false,
          # TODO: change for cluster
          # "count" => -1,
          # "cluster" => true,
          "count" => 1,
          "cluster" => false,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        },
        "monasca-master" => {
          "unique" => true,
          "count" => 1,
          "cluster" => false,
          "admin" => true,
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
    non_db_nodes = nodes.reject do |n|
      # Do not deploy monasca-server to the node running database cluster (already running mariadb)
      n.roles.include?("database-server") && n[:database][:sql_engine] == "mysql"
    end

    monasca_server = select_nodes_for_role(non_db_nodes, "monasca-server", "monitoring") || []

    log_agent_nodes = select_nodes_for_role(nodes, "monasca-log-agent", "compute") || []
    agent_nodes = select_nodes_for_role(nodes, "monasca-agent") || []

    master_nodes = nodes.select { |n| n.intended_role == "admin" || n.name.start_with?("crowbar.") }
    master_node = master_nodes.empty? ? nodes.first : master_nodes.first

    base["deployment"][@bc_name]["elements"] = {
      "monasca-master" => [master_node.name],
      "monasca-server" => monasca_server.empty? ? [] : [monasca_server.first.name],
      "monasca-agent" => agent_nodes.map { |x| x.name },
      "monasca-log-agent" => log_agent_nodes.map { |x| x.name }
    }

    base["attributes"][@bc_name]["database_instance"] =
      find_dep_proposal("database")
    base["attributes"][@bc_name]["keystone_instance"] =
      find_dep_proposal("keystone")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name][:agent][:keystone][:service_password] = random_password
    base["attributes"][@bc_name][:log_agent][:keystone][:service_password] = random_password
    base["attributes"][@bc_name][:master][:tsdb_mon_api_password] = random_password
    base["attributes"][@bc_name][:master][:tsdb_mon_persister_password] = random_password
    base["attributes"][@bc_name][:master][:cassandra_admin_password] = random_password
    base["attributes"][@bc_name][:master][:database_notification_password] = random_password
    base["attributes"][@bc_name][:master][:database_monapi_password] = random_password
    base["attributes"][@bc_name][:master][:database_thresh_password] = random_password
    base["attributes"][@bc_name][:master][:database_logapi_password] = random_password
    base["attributes"][@bc_name][:master][:keystone_monasca_operator_password] = random_password
    base["attributes"][@bc_name][:master][:keystone_monasca_agent_password] = random_password
    base["attributes"][@bc_name][:master][:keystone_admin_agent_password] = random_password
    base["attributes"][@bc_name][:master][:database_grafana_password] = random_password

    @logger.debug("Monasca create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "monasca-master"
    validate_one_for_role proposal, "monasca-server"
    nodes = proposal["deployment"][@bc_name]["elements"]
    nodes["monasca-server"].each do |node|
      n = NodeObject.find_node_by_name(node)
      if n.roles.include?("database-server") && n[:database][:sql_engine] == "mysql"
        validation_error(
          "monasca-server role cannot be deployed to the node with other MariaDB instance."
        )
      end
      unless nodes["monasca-agent"].include? node
         validation_error("All monasca-server node(s) need monasca-agent role too.")
      end
    end

    unless network_present? proposal["attributes"][@bc_name]["network"]
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.invalid_network",
        network: proposal["attributes"][@bc_name]["network"]
      )
    end

    # TODO: uncomment for cluster support
    # if !nodes.key?("monasca-server") ||
    #     (nodes["monasca-server"].length != 1 && nodes["monasca-server"].length != 3)
    #   validation_error("Need either one or three monasca-server node(s).")
    # end
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

  def network_present?(network_name)
    net_svc = NetworkService.new @logger
    network_proposal = Proposal.find_by(barclamp: net_svc.bc_name, name: "default")
    !network_proposal["attributes"]["network"]["networks"][network_name].nil?
  end
end
