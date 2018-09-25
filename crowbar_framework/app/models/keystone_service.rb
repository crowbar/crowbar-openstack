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

class KeystoneService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "keystone"
  end
# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "keystone-server" => {
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
    answer << { "barclamp" => "database", "inst" => role.default_attributes["keystone"]["database_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["keystone"]["rabbitmq_instance"] }
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")

    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["keystone"]["elements"] = {
        "keystone-server" => [controller[:fqdn]]
      }
    end

    base["attributes"][@bc_name][:service][:token] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "keystone-server"

    api_versions = ["2.0", "3"]
    unless api_versions.include? proposal["attributes"][@bc_name]["api"]["version"]
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.api_version",
        api_version: proposal[:attributes][@bc_name][:api][:version]
      )
    end

    # Using domains requires API Version 3 or newer
    if proposal["attributes"][@bc_name]["domain_specific_drivers"] &&
        proposal["attributes"][@bc_name]["api"]["version"].to_f < 3.0
      validation_error I18n.t("barclamp.#{@bc_name}.validation.enable_keystone_api")
    end

    # validate the password hash configuration
    if proposal["attributes"][@bc_name]["identity"]["password_hash_rounds"]
      password_hash_rounds = proposal["attributes"][@bc_name]["identity"]["password_hash_rounds"]
      case proposal["attributes"][@bc_name]["identity"]["password_hash_algorithm"]
      when "bcrypt"
        if password_hash_rounds < 4 || password_hash_rounds > 31
          validation_error I18n.t("barclamp.#{@bc_name}.validation.bcrypt_password_hash_rounds")
        end
      when "scrypt"
        if password_hash_rounds < 1 || password_hash_rounds > 31
          validation_error I18n.t("barclamp.#{@bc_name}.validation.scrypt_password_hash_rounds")
        end
      when "pbkdf_sha512"
        if password_hash_rounds < 1 || password_hash_rounds > (1 << 32) - 1
          validation_error I18n.t("barclamp.#{@bc_name}.validation.pbkdf_sha512_password_hash_rounds")
        end
      end
    end

    keystone_timeout = proposal["attributes"]["keystone"]["token_expiration"]
    horizon_proposal = Proposal.find_by(barclamp: "horizon", name: "default")
    unless horizon_proposal.nil?
      horizon_timeout = horizon_proposal["attributes"]["horizon"]["session_timeout"]

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
    @logger.debug("Keystone apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "keystone-server")

    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["keystone", "ha", "enabled"], ha_enabled, server_elements, vip_networks)
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

    # Save current keystone endpoints to all keystone-server nodes.
    all_nodes.each do |n|
      node = NodeObject.find_by_name(n)
      unless node[:keystone].nil?
        node[:keystone][:endpoint] = {
          insecure: node[:keystone][:ssl][:insecure],
          protocol: node[:keystone][:api][:protocol],
          internal_url_host: node[:keystone][:api][:internal_url_host],
          port: node[:keystone][:api][:admin_port]
        }
        node.save
      end
    end

    @logger.debug("Keystone apply_role_pre_chef_call: leaving")
  end

  def apply_role_post_chef_call(old_role, role, all_nodes)
    @logger.debug("Keystone apply_role_post_chef_call: entering #{all_nodes.inspect}")

    # Save current keystone endpoints to all keystone-server nodes.
    all_nodes.each do |n|
      node = NodeObject.find_by_name(n)
      node[:keystone][:endpoint] = {
        insecure: node[:keystone][:ssl][:insecure],
        protocol: node[:keystone][:api][:protocol],
        internal_url_host: node[:keystone][:api][:internal_url_host],
        port: node[:keystone][:api][:admin_port]
      }
      node.save
    end

    # as we are overriding the apply_role_post_chef_call we have to call save_config_to_databag
    # manually. We could also call super here.
    save_config_to_databag(old_role, role)

    @logger.debug("Keystone apply_role_post_chef_call: leaving")
  end
end

