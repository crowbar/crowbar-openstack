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
          # create
          # new_resource can have password defined or not;
          # search a user
          # if found,
          #   if password hashes match
          #     do nothing
          #   else
          #     update password
          # else
          #   create user (with or without password)
          nr = new_resource
          username = "'#{client.escape(nr.username)}'"
          host = "'#{client.escape(nr.host)}'"
          userspec = "#{username}@#{host}"
          createuser = "CREATE USER IF NOT EXISTS #{userspec}"
          if nr.password
            password = "'#{client.escape(nr.password)}'"
            alteruser = "ALTER USER #{userspec} IDENTIFIED BY #{password}"
            createuser = "#{createuser} IDENTIFIED BY #{password}"
          end

          checkqry = "SELECT user,host FROM mysql.user WHERE user=#{username} AND host=#{host}"
          if client.query(checkqry).count > 0
            # PASSWORD is the mysql's internal password hashing function
            checkqry = "#{checkqry} AND password=PASSWORD(#{password})"
            if nr.password && client.query(checkqry).count.zero?
              Chef::Log.info("Updating password : #{userspec}")
              query = alteruser
            else
              # user found but either passowrd not defied or no change
              query = nil
            end
          else
            Chef::Log.info("Creating user #{userspec}")
            query = createuser
          end
          client.query(query) if query
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

          username = client.escape(new_resource.username)
          host = client.escape(new_resource.host)

          # test the presence of privileges
          privs = {}
          if new_resource.privileges == [:all]
            privs = { "ALL" => false }
          else
            new_resource.privileges.each { |p| privs[p] = false }
          end

          ssl_set = false

          client.query("SHOW GRANTS FOR '#{username}'@'#{host}'").each do |row|
            row.each do |grant, val|
              # example of vals:
              # GRANT USAGE ON *.* TO 'nova'@'%' IDENTIFIED BY PASSWORD '..' REQUIRE SSL
              # GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, ALTER ON `nova`.* TO 'nova'@'%'
              ssl_set = true if val.include?("REQUIRE SSL")
              # make sure to check privileges for selected database
              next unless db_name == "*" || val.include?("\`#{db_name}\`")
              privs.keys.each do |priv|
                privs[priv] = true if val.include? priv
              end
            end
          end

          correct_privileges = privs.reject { |priv, present| present }.empty? &&
            (ssl_set == new_resource.require_ssl)

          return if correct_privileges

          # grant
          Chef::Log.info("Granting privileges for '#{new_resource.username}@#{new_resource.host}'")

          password = client.escape(new_resource.password)
          requires = new_resource.require_ssl ? "SSL" : "NONE"

          grant_sql = "GRANT #{new_resource.privileges.join(",")}"
          grant_sql += " ON #{db_name}.#{tbl_name}"
          grant_sql += " TO '#{username}'@'#{host}'"
          grant_sql += " IDENTIFIED BY '#{password}'"
          grant_sql += " REQUIRE #{requires}"
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
