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

class OctaviaService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "octavia"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "octavia-api" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "octavia-health-manager" => {
          "unique" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "octavia-housekeeping" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "octavia-worker" => {
          "unique" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => false
        }
      }
    end
  end


  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "nova", "inst" => role.default_attributes["octavia"]["nova_instance"] }
    answer << { "barclamp" => "neutron", "inst" => role.default_attributes["octavia"]["neutron_instance"] }
    answer << { "barclamp" => "barbican", "inst" => role.default_attributes["octavia"]["barbican_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["octavia"]["keystone_instance"] }
    answer << { "barclamp" => "glance", "inst" => role.default_attributes["octavia"]["glance_instance"] }
    answer
  end

  def save_proposal!(prop, options = {})
    # Fill in missing defaults for infoblox grid configurations
    if prop.raw_data[:attributes][:octavia][:use_infoblox]
      prop.raw_data[:attributes][:octavia][:infoblox][:grids].each do |grid|
        defaults = prop.raw_data["attributes"]["octavia"]["infoblox"]["grid_defaults"]
        defaults.each_key.each do |d|
          unless grid.key?(d)
            grid[d] = defaults[d]
          end
        end
      end
    end

    with_lock @bc_name do
      db = Chef::DataBagItem.new
      db.data_bag "octavia"
      db["id"] = "certs"
      db["server_ca_cert"] = ""
      db["server_ca_key"] = ""
      db["client_ca"] = ""
      db["client_cert_and_key"] = ""
      db.save
    end

    super(prop, options)
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"][@bc_name]["nova_instance"] = find_dep_proposal("nova")
    base["attributes"][@bc_name]["neutron_instance"] = find_dep_proposal("neutron")
    base["attributes"][@bc_name]["barbican_instance"] = find_dep_proposal("barbican")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")

    controller_nodes = nodes.select { |n| n.intended_role == "controller" }
    controller_node = controller_nodes.first
    controller_node ||= nodes.first

    #TODO: network_nodes I don't know if are required
    network_nodes = nodes.select { |n| n.intended_role == "network" }
    network_nodes = [controller_node] if network_nodes.empty?

    worker_nodes = nodes - [controller_node] - [network_nodes]

    base["deployment"]["octavia"]["elements"] = {
        "octavia-api" => [controller_node[:fqdn]],
        "octavia-health-manager" => [controller_node[:fqdn]],
        "octavia-housekeeping" => [controller_node[:fqdn]],
        "octavia-worker" => worker_nodes.map(&:name)
    } unless nodes.nil? || nodes.length.zero?

    base["attributes"][@bc_name]["db"]["password"] = random_password
    base["attributes"][@bc_name]["health-manager"]["heartbeat_key"] = random_password
    base["attributes"][@bc_name]["service_password"] = random_password

    # with_lock @bc_name do
    #   db = Chef::DataBagItem.new
    #   db.data_bag "octavia"
    #   db["id"] = "octavia"
    #   db["server_ca_cert"] = ""
    #   db["server_ca_key"] = ""
    #   db["client_ca"] = ""
    #   db["client_cert_and_key"] = ""
    #   db.save
    # end

    base
  end

  # TODO: Validations

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Octavia apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # TODO: apply_role_pre_chef_call
    @logger.debug("Octavia apply_role_pre_chef_call: leaving")
  end
end
