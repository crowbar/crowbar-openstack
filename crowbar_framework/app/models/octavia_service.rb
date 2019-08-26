#
# Copyright 2019, SUSE LINUX Products GmbH
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

require "openssl"

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
        "octavia-backend" => {
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
    answer << {
      "barclamp" => "nova",
      "inst" => role.default_attributes["octavia"]["nova_instance"]
    }
    answer << {
      "barclamp" => "neutron",
      "inst" => role.default_attributes["octavia"]["neutron_instance"]
    }
    answer << {
      "barclamp" => "barbican",
      "inst" => role.default_attributes["octavia"]["barbican_instance"]
    }
    answer << {
      "barclamp" => "keystone",
      "inst" => role.default_attributes["octavia"]["keystone_instance"]
    }
    answer << {
      "barclamp" => "glance",
      "inst" => role.default_attributes["octavia"]["glance_instance"]
    }
    answer
  end

  def save_proposal!(prop, options = {})
    super(prop, options)
  end

  def validate_proposal_certs(certs)
    invalid = certs["server_ca_cert_path"] == "" || certs["server_ca_key_path"] == "" ||
      certs["client_ca_cert_path"] == "" || certs["client_cert_and_key_path"] == ""

    error_text = I18n.t("barclamp.#{@bc_name}.validation.certificates_not_empty")
    validation_error error_text if invalid
  end

  def validate_proposal_passphrase(certs)
    error_text = I18n.t("barclamp.#{@bc_name}.validation.passphrase_not_empty")
    validation_error error_text if certs["passphrase"] == ""
  end

  def validate_proposal_ssh(proposal)
    ssh_access = proposal["attributes"]["octavia"]["amphora"]["ssh_access"]
    invalid = ssh_access["enabled"] && ssh_access["keyname"] == ""

    error_text = I18n.t("barclamp.#{@bc_name}.validation.keyname_not_empty")
    validation_error error_text if invalid
  end

  def validate_proposal_after_save(proposal)
    certs = proposal["attributes"]["octavia"]["certs"]

    validate_proposal_certs(certs)
    validate_proposal_passphrase(certs)
    validate_proposal_ssh(proposal)

    super
  end

  def create_poposal_password(base)
    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name][:health_manager][:heartbeat_key] = random_password
    base["attributes"][@bc_name][:service_password] = random_password
  end

  def create_proposal_set_nodes(base, nodes)
    controller_nodes = nodes.select { |n| n.intended_role == "controller" }
    controller_node = controller_nodes.first
    controller_node ||= nodes.first

    unless nodes.nil? || nodes.empty?
      base["deployment"]["octavia"]["elements"] = {
        "octavia-api" => [controller_node[:fqdn]],
        "octavia-backend" => [controller_node[:fqdn]]
      }
    end
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? || n.admin? }

    base["attributes"][@bc_name]["nova_instance"] = find_dep_proposal("nova")
    base["attributes"][@bc_name]["neutron_instance"] = find_dep_proposal("neutron")
    base["attributes"][@bc_name]["barbican_instance"] = find_dep_proposal("barbican")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")

    create_proposal_set_nodes(base, nodes)
    create_poposal_password(base)

    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("octavia apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    if old_role
      all_nodes.each do |n|
        node = ::Node.find_by_name(n)
        node[:octavia][:old_amphora] = old_role.default_attributes["octavia"]["amphora"]
        node.save
      end
    end

    vip_networks = ["admin", "public"]

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "octavia-api")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    role.save if prepare_role_for_ha_with_haproxy(role, ["octavia", "ha", "enabled"],
                                                  ha_enabled, server_elements, vip_networks)

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks(server_elements, vip_networks)

    @logger.debug("octavia apply_role_pre_chef_call: leaving")
  end
end
