#
# Cookbook Name:: cinder
# Recipe:: sql
#
# Copyright 2010-2011, Opscode, Inc.
# Copyright 2011, Dell, Inc.
# Copyright 2012, Dell, Inc.
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

if node[:cinder][:use_gitrepo]
  cinder_path = "/opt/cinder"
  venv_path = node[:cinder][:use_virtualenv] ? "#{cinder_path}/.venv" : nil
  venv_prefix = node[:cinder][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil
end

env_filter = " AND database_config_environment:database-config-#{node[:cinder][:database_instance]}"
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

sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
Chef::Log.info("Database server found at #{sql_address}")

db_conn = { :host => sql_address,
            :username => "db_maker",
            :password => sql[:database][:db_maker_password] }

# Create the Cinder Database
database "create #{node[:cinder][:db][:database]} database" do
    connection db_conn
    database_name node[:cinder][:db][:database]
    provider db_provider
    action :create
end

database_user "create cinder database user" do
    host '%' 
    connection db_conn
    username node[:cinder][:db][:user]
    password node[:cinder][:db][:password]
    provider db_user_provider
    action :create
end

database_user "grant database access for cinder database user" do
    connection db_conn
    username node[:cinder][:db][:user]
    password node[:cinder][:db][:password]
    database_name node[:cinder][:db][:database]
    host '%'
    privileges privs
    provider db_user_provider
    action :grant
end

execute "cinder-manage db sync" do
  command "#{venv_prefix}cinder-manage db sync"
  action :run
end

# save data so it can be found by search
node.save

