#
# Copyright 2014, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  class Recipe
    # Helpers wrapping CrowbarOpenStackHelper, provided for convenience for
    # direct calls from recipes.
    # We prefix the method names with "fetch_" because the return value should
    # still be put in a local variable (to avoid spamming the logs).
    def fetch_database_settings(barclamp=@cookbook_name)
      CrowbarOpenStackHelper.database_settings(node, barclamp)
    end

    def fetch_database_connection_string(db_auth, barclamp = @cookbook_name)
      db_settings = CrowbarOpenStackHelper.database_settings(node, barclamp)
      CrowbarOpenStackHelper.database_connection_string(db_settings, db_auth)
    end

    def fetch_rabbitmq_settings(barclamp=@cookbook_name)
      CrowbarOpenStackHelper.rabbitmq_settings(node, barclamp)
    end
  end
end

# Helpers wrapping CrowbarOpenStackHelper, provided for convenience for direct
# calls from templates.
# We prefix the method names with "fetch_" because the return value should
# still be put in a local variable (to avoid spamming the logs).
class Chef
  class Resource
    class Template
      def fetch_database_settings(barclamp=@cookbook_name)
        CrowbarOpenStackHelper.database_settings(node, barclamp)
      end

      def fetch_database_connection_string(db_auth, barclamp = @cookbook_name)
        db_settings = CrowbarOpenStackHelper.database_settings(node, barclamp)
        CrowbarOpenStackHelper.database_connection_string(db_settings, db_auth)
      end

      def fetch_rabbitmq_settings(barclamp=@cookbook_name)
        CrowbarOpenStackHelper.rabbitmq_settings(node, barclamp)
      end
    end
  end
end

class CrowbarOpenStackHelper
  def self.database_settings(node, barclamp)
    instance = node[barclamp][:database_instance] || "default"

    # Cache the result for each cookbook in an instance variable hash. This
    # cache needs to be invalidated for each chef-client run from chef-client
    # daemon (which are all in the same process); so use the ohai time as a
    # marker for that.
    if @database_settings_cache_time != node[:ohai_time]
      if @database_settings
        Chef::Log.info("Invalidating database settings cache " \
                       "on behalf of #{barclamp}")
      end
      @database_settings = nil
      @database_settings_cache_time = node[:ohai_time]
    end

    if @database_settings && @database_settings.include?(instance)
      Chef::Log.info("Database server found at #{@database_settings[instance][:address]} [cached]")
    else
      @database_settings ||= Hash.new
      database = get_node(node, "database-server", "database", instance)

      if database.nil?
        Chef::Log.warn("No database server found!")
      else
        address = CrowbarDatabaseHelper.get_listen_address(database)
        backend_name = DatabaseLibrary::Database::Util.get_backend_name(database)

        @database_settings[instance] = {
          address: address,
          url_scheme: backend_name,
          backend_name: backend_name,
          provider: DatabaseLibrary::Database::Util.get_database_provider(database),
          user_provider: DatabaseLibrary::Database::Util.get_user_provider(database),
          privs: DatabaseLibrary::Database::Util.get_default_priviledges(database),
          connection: {
            host: address,
            username: "db_maker",
            password: database["database"][:db_maker_password]
          }
        }

        Chef::Log.info("Database server found at #{@database_settings[instance][:address]}")
      end
    end

    @database_settings[instance]
  end

  def self.database_connection_string(db_settings, db_auth)
    db_conn_scheme = db_settings[:url_scheme]
    db_charset = ""

    if db_conn_scheme == "mysql"
      db_conn_scheme = "mysql+pymysql"
      db_charset = "?charset=utf8"
    end

    "#{db_conn_scheme}://" \
    "#{db_auth[:user]}:#{db_auth[:password]}@#{db_settings[:address]}/" \
    "#{db_auth[:database]}" \
    "#{db_charset}"
  end

  def self.rabbitmq_settings(node, barclamp)
    instance = node[barclamp][:rabbitmq_instance] || "default"
    config = BarclampLibrary::Barclamp::Config.load("openstack", "rabbitmq", instance)

    Chef::Log.warn("No RabbitMQ server found!") if config.empty?
    Chef::Log.info("RabbitMQ server found at #{config[:address]}") unless config.empty?

    config
  end

  # Verify uid for user.
  def self.check_user(node, expected_username, expected_uid)
    node["etc"]["passwd"].each do |username, attrs|
      if username == expected_username
        if attrs["uid"] != expected_uid
          message = "user #{username} has uid #{attrs["uid"]} but " \
            "expected #{expected_uid}"
          Chef::Log.fatal(message)
          raise message
        else
          break
        end
      end

      next unless attrs["uid"] == expected_uid

      message = "#{expected_uid} already in use by user #{username}"
      Chef::Log.fatal(message)
      raise message
    end
  end

  # Verify gid for group.
  def self.check_group(node, expected_groupname, expected_gid)
    node["etc"]["group"].each do |groupname, attrs|
      if groupname == expected_groupname
        if attrs["gid"] != expected_gid
          message = "group #{username} has gid #{attrs["gid"]} but " \
            "expected #{expected_gid}"
          Chef::Log.fatal(message)
          raise message
        else
          break
        end
      end

      next unless attrs["gid"] == expected_gid

      message = "#{expected_gid} already in use by group #{groupname}"
      Chef::Log.fatal(message)
      raise message
    end
  end

  private

  def self.get_node(node, role, barclamp, instance)
    result = nil

    if node.roles.include?(role) && \
        node.key?(barclamp) && \
        node[barclamp].key?("config") && \
        node[barclamp]["config"]["environment"] == "#{barclamp}-config-#{instance}"
      result = node
    else
      nodes, _, _ = Chef::Search::Query.new.search(:node, "roles:#{role} AND #{barclamp}_config_environment:#{barclamp}-config-#{instance}")
      result = nodes.first unless nodes.empty?
    end

    result
  end
end
