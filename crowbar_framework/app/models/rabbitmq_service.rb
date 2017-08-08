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

class RabbitmqService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "rabbitmq"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "rabbitmq-server" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer
  end

  def create_proposal
    @logger.debug("Rabbitmq create_proposal: entering")
    base = super
    @logger.debug("Rabbitmq create_proposal: done with base")

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? }
    nodes.delete_if { |n| n.admin? } if nodes.size > 1
    controller = nodes.find { |n| n if n.intended_role == "controller" } || nodes.first
    base["deployment"]["rabbitmq"]["elements"] = {
      "rabbitmq-server" => [controller.name]
    }

    base["attributes"][@bc_name]["password"] = random_password
    base["attributes"][@bc_name]["trove"]["password"] = random_password

    @logger.debug("Rabbitmq create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Rabbitmq apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    rabbitmq_elements, rabbitmq_nodes, rabbitmq_ha_enabled = role_expand_elements(role, "rabbitmq-server")
    Openstack::HA.set_controller_role(rabbitmq_nodes) if rabbitmq_ha_enabled

    role.save if prepare_role_for_ha(role, ["rabbitmq", "ha", "enabled"], rabbitmq_ha_enabled)
    reset_sync_marks_on_clusters_founders(rabbitmq_elements)

    net_svc = NetworkService.new @logger
    # Allocate public IP if rabbitmq should listen on public interface
    if role.default_attributes["rabbitmq"]["listen_public"]
      rabbitmq_nodes.each do |n|
        net_svc.allocate_ip "default", "public", "host", n
      end
    end

    if rabbitmq_ha_enabled
      unless rabbitmq_elements.length == 1 && PacemakerServiceObject.is_cluster?(rabbitmq_elements[0])
        raise "Internal error: HA enabled, but element is not a cluster"
      end
      cluster = rabbitmq_elements[0]
      rabbitmq_vhostname = "#{role.name.gsub("-config", "")}-#{PacemakerServiceObject.cluster_name(cluster)}.#{Crowbar::Settings.domain}".tr("_", "-")
      net_svc.allocate_virtual_ip "default", "admin", "host", rabbitmq_vhostname
      if role.default_attributes["rabbitmq"]["listen_public"]
        net_svc.allocate_virtual_ip "default", "public", "host", rabbitmq_vhostname
      end
      # rabbitmq, on start, needs to have the virtual hostname resolvable; so
      # let's force a dns update now
      ensure_dns_uptodate
    end

    @logger.debug("Rabbitmq apply_role_pre_chef_call: leaving")
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "rabbitmq-server"

    attributes = proposal["attributes"][@bc_name]

    # HA validation
    servers = proposal["deployment"][@bc_name]["elements"]["rabbitmq-server"]
    unless servers.nil? || servers.first.nil? || !is_cluster?(servers.first)
      storage_mode = attributes["ha"]["storage"]["mode"]
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.unknown_mode", storage_mode: storage_mode
      ) unless %w(shared drbd).include?(storage_mode)

      if storage_mode == "shared"
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.no_device"
        ) if attributes["ha"]["storage"]["shared"]["device"].blank?
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.no_filesystem"
        ) if attributes["ha"]["storage"]["shared"]["fstype"].blank?
      elsif storage_mode == "drbd"
        cluster = servers.first
        role = available_clusters[cluster]
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.drbd", cluster_name: cluster_name(cluster)
        ) unless role.default_attributes["pacemaker"]["drbd"]["enabled"]
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_size"
        ) if attributes["ha"]["storage"]["drbd"]["size"] <= 0
      end
    end

    super
  end

  def save_config_to_databag(old_role, role)
    @logger.debug("#{@bc_name} save_config_to_databag: entering")
    if role.nil?
      config = nil
    else
      _elements, nodes, _ha_enabled = role_expand_elements(role, "rabbitmq-server")
      node = NodeObject.find_node_by_name(nodes.first)
      address = node[:rabbitmq][:address]
      user = role.default_attributes["rabbitmq"]["user"]
      password = role.default_attributes["rabbitmq"]["password"]
      vhost = role.default_attributes["rabbitmq"]["vhost"]
      use_ssl = role.default_attributes["rabbitmq"]["ssl"]["enabled"]
      client_ca_certs = if use_ssl && !role.default_attributes["rabbitmq"]["ssl"]["insecure"]
        role.default_attributes["rabbitmq"]["ssl"]["client_ca_certs"]
      end

      port = if use_ssl
        role.default_attributes["rabbitmq"]["ssl"]["port"]
      else
        role.default_attributes["rabbitmq"]["port"]
      end

      config = {
        address: address,
        port: port,
        user: user,
        password: password,
        vhost: "/#{vhost}",
        use_ssl: use_ssl,
        client_ca_certs: client_ca_certs,
        url: "rabbit://#{user}:#{password}@#{address}:#{port}/#{vhost}"
      }
    end

    instance = Crowbar::DataBagConfig.instance_from_role(old_role, role)
    Crowbar::DataBagConfig.save("openstack", instance, @bc_name, config)
    @logger.debug("#{@bc_name} save_config_to_databag: leaving")
  end
end

