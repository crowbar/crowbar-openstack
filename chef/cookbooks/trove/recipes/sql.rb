#
# Copyright 2016 SUSE Linux GmbH
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
# Cookbook Name:: trove
# Recipe:: sql
#

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"


database "create #{node[:trove][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:trove][:db][:database]
  provider db_settings[:provider]
  action :create
end

database_user "create trove database user" do
  host "%"
  connection db_settings[:connection]
  username node[:trove][:db][:user]
  password node[:trove][:db][:password]
  provider db_settings[:user_provider]
  action :create
end

database_user "grant database access for trove database user" do
  connection db_settings[:connection]
  username node[:trove][:db][:user]
  password node[:trove][:db][:password]
  database_name node[:trove][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
end
