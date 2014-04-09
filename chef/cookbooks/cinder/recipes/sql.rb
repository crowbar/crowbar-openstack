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

sql = get_instance('roles:database-server')

include_recipe "database::client"
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
include_recipe "#{backend_name}::client"
include_recipe "#{backend_name}::python-client"

db_provider = Chef::Recipe::Database::Util.get_database_provider(sql)
db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql)
privs = Chef::Recipe::Database::Util.get_default_priviledges(sql)

sql_address = CrowbarDatabaseHelper.get_listen_address(sql)
Chef::Log.info("Database server found at #{sql_address}")

db_conn = { :host => sql_address,
            :username => "db_maker",
            :password => sql[:database][:db_maker_password] }

crowbar_pacemaker_sync_mark "wait-cinder_database"

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
  user node[:cinder][:user]
  group node[:cinder][:group]
  # On SUSE, we only need this when HA is enabled as the init script is doing
  # this (but that creates races with HA)
  only_if { node.platform != "suse" || node[:cinder][:ha][:enabled] }
end

crowbar_pacemaker_sync_mark "create-cinder_database"

# save data so it can be found by search
node.save

