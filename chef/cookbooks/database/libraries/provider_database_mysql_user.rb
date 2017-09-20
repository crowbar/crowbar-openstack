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

require File.join(File.dirname(__FILE__), "provider_database_mysql")

class Chef
  class Provider
    class Database
      class MysqlUser < Chef::Provider::Database::Mysql

        def load_current_resource
          Gem.clear_paths
          require "mysql2"
          @current_resource = Chef::Resource::DatabaseUser.new(@new_resource.name)
          @current_resource.username(@new_resource.name)
          @current_resource
        end

        def action_create
          Chef::Log.info("Creating user '#{new_resource.username}@#{new_resource.host}'")
          username = client.escape(new_resource.username)
          host = client.escape(new_resource.host)
          create_sql = "CREATE USER IF NOT EXISTS '#{username}'@'#{host}'"
          if new_resource.password
            password = client.escape(new_resource.password)
            create_sql += " IDENTIFIED BY '#{password}'"
          end
          client.query(create_sql)
        ensure
          close_client
        end

        def action_drop
          # drop
          Chef::Log.info("Dropping user '#{new_resource.username}@#{new_resource.host}'")

          username = client.escape(new_resource.username)
          host = client.escape(new_resource.host)
          drop_sql = "DROP USER IF EXISTS '#{username}'@'#{host}'"
          client.query(drop_sql)
        ensure
          close_client
        end

        def action_grant
          db_name = new_resource.database_name || "*"
          tbl_name = new_resource.table || "*"

          # test
          incorrect_privileges = false
          test_sql = client.prepare("SELECT * from mysql.db WHERE User = ? AND Host = ? AND Db = ?")
          results = test_sql.execute(
            new_resource.username,
            new_resource.host,
            db_name
          )
          incorrect_privileges = true if results.size.zero?
          # These should all by 'Y'
          results.each do |result|
            new_resource.privileges.each do |privileges|
              key = "#{privileges.capitalize}_priv"
              incorrect_privileges = true if privileges[key] != "Y"
            end
          end

          # grant
          return unless incorrect_privileges
          Chef::Log.info("Granting privileges for '#{new_resource.username}@#{new_resource.host}'")

          username = client.escape(new_resource.username)
          host = client.escape(new_resource.host)
          password = client.escape(new_resource.password)

          grant_sql = "GRANT #{new_resource.privileges.join(",")}"
          grant_sql += " ON #{db_name}.#{tbl_name}"
          grant_sql += " TO '#{username}'@'#{host}'"
          grant_sql += " IDENTIFIED BY '#{password}'"
          grant_sql += " REQUIRE SSL" if new_resource.require_ssl
          client.query(grant_sql)
          client.query("FLUSH PRIVILEGES")
        ensure
          close_client
        end

        private

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
