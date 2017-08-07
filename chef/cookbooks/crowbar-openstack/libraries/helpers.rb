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
      Chef::Log.info("RabbitMQ settings found [cached]")
    else
      @rabbitmq_settings ||= Hash.new
      rabbits = get_nodes(node, "rabbitmq-server", "rabbitmq", instance)

      if rabbits.empty?
        Chef::Log.warn("No RabbitMQ server found!")
      else
        one_rabbit = rabbits.first
        client_ca_certs = if one_rabbit[:rabbitmq][:ssl][:enabled] && \
            !one_rabbit[:rabbitmq][:ssl][:insecure]
          one_rabbit[:rabbitmq][:ssl][:client_ca_certs]
        end

        if one_rabbit[:rabbitmq][:cluster]
          # transport_url format:
          # https://docs.openstack.org/oslo.messaging/latest/reference/transport.html#oslo_messaging.TransportURL
          rabbit_hosts = rabbits.map do |rabbit|
            port = if rabbit[:rabbitmq][:ssl][:enabled]
              rabbit[:rabbitmq][:ssl][:port]
            else
              rabbit[:rabbitmq][:port]
            end
            url = "#{rabbit[:rabbitmq][:user]}:"
            url << "#{rabbit[:rabbitmq][:password]}@"
            url << "#{rabbit[:rabbitmq][:address]}:#{port}"
            url << "/#{rabbit[:rabbitmq][:vhost]}" unless rabbit.equal? rabbits.first
            url.prepend("rabbit://") if rabbit.equal? rabbits.first

            url
          end

          trove_rabbit_hosts = rabbits.map do |rabbit|
            port = if rabbit[:rabbitmq][:ssl][:enabled]
              rabbit[:rabbitmq][:ssl][:port]
            else
              rabbit[:rabbitmq][:port]
            end

            url = "#{rabbit[:rabbitmq][:trove][:user]}:"
            url << "#{rabbit[:rabbitmq][:trove][:password]}@"
            url << "#{rabbit[:rabbitmq][:address]}:#{port}"
            url << "/#{rabbit[:rabbitmq][:trove][:vhost]}" unless rabbit.equal? rabbits.first
            url.prepend("rabbit://") if rabbit.equal? rabbits.first
          end

          @rabbitmq_settings[instance] = {
            cluster: true,
            ha_queues: true,
            durable_queues: true,
            use_ssl: one_rabbit[:rabbitmq][:ssl][:enabled],
            client_ca_certs: client_ca_certs,
            url: rabbit_hosts.join(","),
            trove_url: trove_rabbit_hosts.join(","),
            pacemaker_resource: "ms-rabbitmq"
          }
          Chef::Log.info("RabbitMQ cluster found")
        else
          rabbit = one_rabbit
          port = if rabbit[:rabbitmq][:ssl][:enabled]
            rabbit[:rabbitmq][:ssl][:port]
          else
            rabbit[:rabbitmq][:port]
          end

          @rabbitmq_settings[instance] = {
            # backwards compatible attributes, remove in cloud8?
            address: rabbit[:rabbitmq][:address],
            port: port,
            user: rabbit[:rabbitmq][:user],
            password: rabbit[:rabbitmq][:password],
            vhost: rabbit[:rabbitmq][:vhost], # end backwards comatible attrs
            cluster: false,
            ha_queues: false,
            durable_queues: false,
            use_ssl: rabbit[:rabbitmq][:ssl][:enabled],
            client_ca_certs: client_ca_certs,
            url: "rabbit://#{rabbit[:rabbitmq][:user]}:" \
              "#{rabbit[:rabbitmq][:password]}@" \
              "#{rabbit[:rabbitmq][:address]}:#{port}/" \
              "#{rabbit[:rabbitmq][:vhost]}",
            trove_url: "rabbit://#{rabbit[:rabbitmq][:trove][:user]}:" \
              "#{rabbit[:rabbitmq][:trove][:password]}@" \
              "#{rabbit[:rabbitmq][:address]}:#{port}/" \
              "#{rabbit[:rabbitmq][:trove][:vhost]}",
            pacemaker_resource: "rabbitmq"
          }

          Chef::Log.info("RabbitMQ server found")
        end
      end
    end

    @rabbitmq_settings[instance]
  end

  def self.get_node(node, role, barclamp, instance)
    result = nil

    if node.roles.include?(role) && \
        node.key?(barclamp) && \
        node[barclamp].key?("config") && \
        node[barclamp]["config"]["environment"] == "#{barclamp}-config-#{instance}"
      result = node
    else
      nodes, = Chef::Search::Query.new.search(:node, "roles:#{role} AND " \
      "#{barclamp}_config_environment:#{barclamp}-config-#{instance}")
      result = nodes.first unless nodes.empty?
    end

    result
  end

  def self.get_nodes(node, role, barclamp, instance)
    nodes, = Chef::Search::Query.new.search(:node, "roles:#{role} AND " \
    "#{barclamp}_config_environment:#{barclamp}-config-#{instance}")
    nodes
  end

  private_class_method :get_node
  private_class_method :get_nodes
end
