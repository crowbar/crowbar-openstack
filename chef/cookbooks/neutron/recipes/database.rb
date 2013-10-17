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

env_filter = " AND database_config_environment:database-config-#{node[:neutron][:database_instance]}" 
sqls = search(:node, "roles:database-server#{env_filter}") || [] 
if sqls.length > 0 
    sql = sqls[0] 
    sql = node if sql.name == node.name 
else 
    sql = node 
end
include_recipe "database::client" 
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql) 
include_recipe "#{backend_name}::client" 
include_recipe "#{backend_name}::python-client"

db_provider = Chef::Recipe::Database::Util.get_database_provider(sql) 
db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql) 
privs = Chef::Recipe::Database::Util.get_default_priviledges(sql) 
url_scheme = backend_name

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
node.set_unless['neutron']['db']['password'] = secure_password
node.set_unless['neutron']['db']['ovs_password'] = secure_password
node.set_unless['neutron']['db']['cisco_password'] = secure_password

sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil? 
Chef::Log.info("Database server found at #{sql_address}") 

db_conn = { :host => sql_address, 
            :username => "db_maker", 
            :password => sql["database"][:db_maker_password] }

props = [ {'db_name' => node[:neutron][:db][:database],
          'db_user' => node[:neutron][:db][:user],
          'db_pass' => node[:neutron][:db][:password],
          'db_conn_name' => 'sql_connection'  },
         {'db_name' => node[:neutron][:db][:ovs_database],
          'db_user' => node[:neutron][:db][:ovs_user],
          'db_pass' => node[:neutron][:db][:ovs_password],
          'db_conn_name' => 'ovs_sql_connection'},
         {'db_name' => node[:neutron][:db][:cisco_database],
          'db_user' => node[:neutron][:db][:cisco_user],
          'db_pass' => node[:neutron][:db][:cisco_password],
          'sql_address_name' => 'cisco_sql_address',
          'db_conn_name' => 'cisco_sql_connection'}
       ]
         
# Create the Neutron Databases
props.each do |prop|
  db_name = prop['db_name']
  db_user = prop['db_user']
  db_pass = prop['db_pass']
  db_conn_name = prop['db_conn_name']
  sql_address_name = prop['sql_address_name']

    database "create #{db_name} neutron database" do
        connection db_conn
        database_name "#{db_name}"
        provider db_provider
        action :create
    end

    database_user "create #{db_user} user in #{db_name} neutron database" do
        connection db_conn
        username "#{db_user}"
        password "#{db_pass}"
        host '%'
        provider db_user_provider
        action :create
    end

    database_user "grant database access for #{db_user} user in #{db_name} neutron database" do
        connection db_conn 
        username "#{db_user}" 
        password "#{db_pass}"
        database_name "#{db_name}"
        host '%' 
        privileges privs 
        provider db_user_provider 
        action :grant 
    end

    node[@cookbook_name][:db][db_conn_name] = "#{url_scheme}://#{db_user}:#{db_pass}@#{sql_address}/#{db_name}"
    unless sql_address_name.nil?
        node[@cookbook_name][:db][sql_address_name] = sql_address
    end
end

node.save
