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

class DatabaseService < PacemakerServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "database"
  end

# turn off nulti proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "database-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def create_proposal
    @logger.debug("Database create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      controller = nodes.find { |n| n.intended_role == "controller" } || nodes.first
      base["deployment"]["database"]["elements"] = {
        "database-server" => [controller[:fqdn]]
      }
    end

    @logger.debug("Database create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "database-server"

    attributes = proposal["attributes"][@bc_name]
    db_engine = attributes["sql_engine"]
    validation_error I18n.t(
      "barclamp.#{@bc_name}.validation.invalid_db_engine",
      db_engine: db_engine
    ) unless %w(mysql postgresql).include?(db_engine)

    # HA validation
    servers = proposal["deployment"][@bc_name]["elements"]["database-server"]
    unless servers.nil? || servers.first.nil? || !is_cluster?(servers.first)
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.ha_postgresql"
      ) unless db_engine == "postgresql"

      storage_mode = attributes["ha"]["storage"]["mode"]
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.unknown_mode_ha",
        storage_mode: storage_mode
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
          "barclamp.#{@bc_name}.validation.drbd_not_enabled",
          cluster_name: cluster_name(cluster)
        ) unless role.default_attributes["pacemaker"]["drbd"]["enabled"]
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_size_drbd"
        ) if attributes["ha"]["storage"]["drbd"]["size"] <= 0
      end
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Database apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    database_elements, database_nodes, database_ha_enabled = role_expand_elements(role, "database-server")
    Openstack::HA.set_controller_role(database_nodes) if database_ha_enabled

    prepare_role_for_ha(role, ["database", "ha", "enabled"], database_ha_enabled)
    reset_sync_marks_on_clusters_founders(database_elements)

    if database_ha_enabled
      net_svc = NetworkService.new @logger
      unless database_elements.length == 1 && PacemakerServiceObject.is_cluster?(database_elements[0])
        raise "Internal error: HA enabled, but element is not a cluster"
      end
      cluster = database_elements[0]
      # Any change in the generation of the vhostname here must be reflected in
      # CrowbarDatabaseHelper.get_ha_vhostname
      database_vhostname = "#{role.name.gsub("-config", "")}-#{PacemakerServiceObject.cluster_name(cluster)}.#{Crowbar::Settings.domain}".tr("_", "-")
      net_svc.allocate_virtual_ip "default", "admin", "host", database_vhostname
    end

    sql_engine = role.default_attributes["database"]["sql_engine"]
    role.default_attributes["database"][sql_engine] = {} if role.default_attributes["database"][sql_engine].nil?
    role.default_attributes["database"]["db_maker_password"] = (old_role && old_role.default_attributes["database"]["db_maker_password"]) || random_password

    if ( sql_engine == "mysql" )
      role.default_attributes["database"]["mysql"]["server_root_password"] = (old_role && old_role.default_attributes["database"]["mysql"]["server_root_password"]) || random_password
      role.default_attributes["database"]["mysql"]["server_repl_password"] = (old_role && old_role.default_attributes["database"]["mysql"]["server_repl_password"]) || random_password
      @logger.debug("setting mysql specific attributes")
    elsif ( sql_engine == "postgresql" )
      # Attribute is not living in "database" namespace, but that's because
      # it's for the postgresql cookbook. We're not using default_attributes
      # because the upstream cookbook use node.set_unless which would override
      # a default attribute.
      role.override_attributes["postgresql"] ||= {}
      role.override_attributes["postgresql"]["password"] ||= {}
      role.override_attributes["postgresql"]["password"]["postgres"] = (old_role && (old_role.override_attributes["postgresql"]["password"]["postgres"] rescue nil)) || random_password
      @logger.debug("setting postgresql specific attributes")
    end

    # Copy the attributes for database/<sql_engine> to <sql_engine> in the
    # role attributes to avoid renaming all attributes everywhere in the
    # postgres and mysql cookbooks
    # (FIXME: is there a better way to achieve this?)
    role.default_attributes[sql_engine] = role.default_attributes["database"][sql_engine]
    role.save

    @logger.debug("Database apply_role_pre_chef_call: leaving")
  end
end

