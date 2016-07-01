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

    def fetch_rabbitmq_settings(barclamp=@cookbook_name)
      CrowbarOpenStackHelper.rabbitmq_settings(node, barclamp)
    end

    def fetch_nodes_with_roles(roles)
      CrowbarOpenStackHelper.fetch_nodes_with_roles(roles)
    end

    def fetch_nodes(expression)
      CrowbarOpenStackHelper.fetch_nodes(expression)
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

      def fetch_rabbitmq_settings(barclamp=@cookbook_name)
        CrowbarOpenStackHelper.rabbitmq_settings(node, barclamp)
      end

      def fetch_nodes_with_roles(roles)
        CrowbarOpenStackHelper.fetch_nodes_with_roles(roles)
      end

      def fetch_nodes(expression)
        CrowbarOpenStackHelper.fetch_nodes(expression)
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

  def self.rabbitmq_settings(node, barclamp)
    instance = node[barclamp][:rabbitmq_instance] || "default"

    # Cache the result for each cookbook in an instance variable hash. This
    # cache needs to be invalidated for each chef-client run from chef-client
    # daemon (which are all in the same process); so use the ohai time as a
    # marker for that.
    if @rabbitmq_settings_cache_time != node[:ohai_time]
      if @rabbitmq_settings
        Chef::Log.info("Invalidating rabbitmq settings cache " \
                       "on behalf of #{barclamp}")
      end
      @rabbitmq_settings = nil
      @rabbitmq_settings_cache_time = node[:ohai_time]
    end

    if @rabbitmq_settings && @rabbitmq_settings.include?(instance)
      Chef::Log.info("RabbitMQ server found at #{@rabbitmq_settings[instance][:address]} [cached]")
    else
      @rabbitmq_settings ||= Hash.new
      rabbit = get_node(node, "rabbitmq-server", "rabbitmq", instance)

      if rabbit.nil?
        Chef::Log.warn("No RabbitMQ server found!")
      else
        @rabbitmq_settings[instance] = {
          address: rabbit[:rabbitmq][:address],
          port: rabbit[:rabbitmq][:port],
          user: rabbit[:rabbitmq][:user],
          password: rabbit[:rabbitmq][:password],
          vhost: rabbit[:rabbitmq][:vhost],
          url: "rabbit://#{rabbit[:rabbitmq][:user]}:" \
            "#{rabbit[:rabbitmq][:password]}@" \
            "#{rabbit[:rabbitmq][:address]}:#{rabbit[:rabbitmq][:port]}/" \
            "#{rabbit[:rabbitmq][:vhost]}"
        }

        Chef::Log.info("RabbitMQ server found at #{@rabbitmq_settings[instance][:address]}")
      end
    end

    @rabbitmq_settings[instance]
  end

  def self.fetch_nodes_with_roles(roles)
    nodes, = Chef::Search::Query.new.search(:node, "roles:#{roles}")
    nodes
  end

  def self.fetch_nodes(expression)
    nodes, = Chef::Search::Query.new.search(:node, expression)
    nodes
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
      nodes, = Chef::Search::Query.new.search(
        :node,
        "roles:#{role} AND #{barclamp}_config_environment:#{barclamp}-config-#{instance}")
      result = nodes.first unless nodes.empty?
    end

    result
  end
end
