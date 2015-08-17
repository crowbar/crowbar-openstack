#
# Cookbook Name:: database
# Library:: DatabaseLibrary
#
# Copyright 2012, SUSE Linux Products GmbH
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
module DatabaseLibrary
    class Database
        class Util
            def self.get_database_provider(node)
                backend = node[:database][:sql_engine]
                db_provider = nil
                case backend
                when "postgresql"
                    db_provider = Chef::Provider::Database::Postgresql
                when "mysql"
                    db_provider = Chef::Provider::Database::Mysql
                else
                    Chef::Log.error("Unsupported Database Provider: #{backend}")
                end
                db_provider
            end

            def self.get_user_provider(node)
                backend = node[:database][:sql_engine]
                db_provider = nil
                case backend
                when "postgresql"
                    db_provider = Chef::Provider::Database::PostgresqlUser
                when "mysql"
                    db_provider = Chef::Provider::Database::MysqlUser
                else
                    Chef::Log.error("Unsupported Database Provider: #{backend}")
                end
                db_provider
            end

            def self.get_backend_name(node)
                node[:database][:sql_engine]
            end

            def self.get_default_priviledges(node)
                backend = node[:database][:sql_engine]
                privs = nil
                case backend
                when "postgresql"
                    privs = [ "CREATE", "CONNECT", "TEMP" ]
                when "mysql"
                    privs = [ "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE",
                          "DROP", "INDEX", "ALTER" ]
                else
                    Chef::Log.error("Unsupported Database Provider: #{backend}")
                end
                privs
            end
        end
    end
end
