#
# Copyright 2016, SUSE
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
    def get_sql_connection
      # get Database data
      db_password = ""
      if node.roles.include? "trove-server"
        db_password = node[:trove][:db][:password]
      else
        # pickup password to database from trove-server node
        node_servers = search(:node, "roles:trove-server") || []
        if node_servers.length > 0
          db_password = node_servers[0][:trove][:db][:password]
        end
      end
      # FIXME: trove uses mysql and the mysql server is currently always
      # running on the same node
      "mysql://#{node[:trove][:db][:user]}:"\
      "#{db_password}@127.0.0.1/"\
      "#{node[:trove][:db][:database]}"
    end

    def get_rabbitmq_trove_settings
      # get rabbitmq-server information
      # NOTE: Trove uses it's own vhost instead of the default one
      rabbitmq_servers = search(:node, "roles:rabbitmq-server") || []
      unless rabbitmq_servers.empty?
        rabbitmq_trove_settings = rabbitmq_servers[0][:rabbitmq][:trove]
      else
        rabbitmq_trove_settings = nil
      end
      rabbitmq_trove_settings
    end
  end
end
