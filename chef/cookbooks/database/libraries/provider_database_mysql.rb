#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require "chef/provider"

class Chef
  class Provider
    class Database
      class Mysql < Chef::Provider

        def load_current_resource
          Gem.clear_paths
          require "mysql2"
          @current_resource = Chef::Resource::Database.new(@new_resource.name)
          @current_resource.database_name(@new_resource.database_name)
          @current_resource
        end

        def action_create
          return if schema_present?(new_resource.database_name)
          Chef::Log.info("Creating schema '#{new_resource.database_name}'")

          database_name = client.escape(new_resource.database_name)
          create_sql = "CREATE SCHEMA IF NOT EXISTS `#{database_name}`"
          if new_resource.encoding
            encoding = client.escape(new_resource.encoding)
            create_sql += " CHARACTER SET = #{encoding}"
          end
          if new_resource.collation
            collation = client.escape(new_resource.collation)
            create_sql += " COLLATE = #{collation}"
          end
          client.query(create_sql)
        ensure
          close_client
        end

        def action_drop
          return unless schema_present?(new_resource.database_name)
          Chef::Log.info("Dropping schema '#{new_resource.database_name}'")

          database_name = client.escape(new_resource.database_name)
          drop_sql = "DROP SCHEMA IF EXISTS `#{database_name}`"
          client.query(drop_sql)
        ensure
          close_client
        end

        private

        def schema_present?(database_name)
          schema_present = false
          test_sql = client.prepare("SHOW SCHEMAS")
          results = test_sql.execute
          results.each do |result|
            schema_present = true if result["Database"] == database_name
          end
          schema_present
        end

        def client
          client_options = {
            host: new_resource.connection[:host],
            socket: new_resource.connection[:socket],
            username: new_resource.connection[:username],
            password: new_resource.connection[:password],
            port: new_resource.connection[:port]
          }
          if new_resource.connection[:ssl][:enabled]
            if new_resource.connection[:ssl][:insecure]
              client_options[:sslverify] = false
            else
              client_options[:sslverify] = true
              client_options[:sslca] = new_resource.connection[:ssl][:ca_certs]
            end
          end
          @client ||= Mysql2::Client.new(client_options)
        end

        def close_client
          @client.close
        rescue
          @client = nil
        end
      end
    end
  end
end
