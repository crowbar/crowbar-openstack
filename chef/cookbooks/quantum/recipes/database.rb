# Copyright 2013 Dell, Inc.
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

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['quantum']['db']['password'] = secure_password
node.set_unless['quantum']['db']['ovs_password'] = secure_password

if node[:quantum][:sql_engine] == "mysql"
    Chef::Log.info("Configuring Quantum to use MySQL backend")

    include_recipe "mysql::client"

    package "python-mysqldb" do
        action :install
    end

    env_filter = " AND mysql_config_environment:mysql-config-#{node[:quantum][:mysql_instance]}"
    mysqls = search(:node, "roles:mysql-server#{env_filter}") || []
    if mysqls.length > 0
        mysql = mysqls[0]
        mysql = node if mysql.name == node.name
    else
        mysql = node
    end

    mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
    Chef::Log.info("Mysql server found at #{mysql_address}")

    props = [ {'db_name' => node[:quantum][:db][:database],
              'db_user' => node[:quantum][:db][:user],
              'db_pass' => node[:quantum][:db][:password],
              'db_conn_name' => 'sql_connection'  },
             {'db_name' => node[:quantum][:db][:ovs_database],
              'db_user' => node[:quantum][:db][:ovs_user],
              'db_pass' => node[:quantum][:db][:ovs_password],
              'db_conn_name' => 'ovs_sql_connection'}
           ]
             
    # Create the Quantum Databases
    props.each do |prop|
      db_name = prop['db_name']
      db_user = prop['db_user']
      db_pass = prop['db_pass']
      db_conn_name = prop['db_conn_name']
      mysql_database "create #{db_name} quantum database" do
          host    mysql_address
          username "db_maker"
          password mysql[:mysql][:db_maker_password]
          database node[:quantum][:db][:database]
          action :create_db
      end

      mysql_database "create quantum database user #{db_user}" do
          host    mysql_address
          username "db_maker"
          password mysql[:mysql][:db_maker_password]
          database node[:quantum][:db][:database]
          action :query
          sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{db_name}.* to '#{db_user}'@'%' IDENTIFIED BY '#{db_pass}';"
      end

      node[@cookbook_name][:db][db_conn_name] = "mysql://#{db_user}:#{db_pass}@#{mysql_address}/#{db_name}"

    end

elsif node[:quantum][:sql_engine] == "sqlite"
    Chef::Log.info("Configuring Quantum to use SQLite backend")
    node[@cookbook_name][:db][:sql_connection] = "sqlite:////var/lib/quantum/quantum.db"
    file "/var/lib/quantum/quantum.db" do
        owner "quantum"
        action :create_if_missing
    end
end

node.save
