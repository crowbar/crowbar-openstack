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

# XXX mysql configuration
# this part should go away once trove supports postgresl

# rubygem-mysql is installed here, although it would normally be the
# database cookbook's responsibility. The database cookbook uses a
# special mysql-chef_gem for this which is Chef 0.11 only.
pkgs = ["mariadb", "python-mysql"]
pkgs.push("ruby#{node["languages"]["ruby"]["version"].to_f}-rubygem-mysql")
pkgs.each do |pkg|
  package pkg
end

service "mysql" do
  action [:start, :enable]
end

# copied from openstack-common/database/db_create_with_user
conn = {
  host: "127.0.0.1",
  port: 3306,
  username: "root"
}

database "create trove database" do
  provider ::Chef::Provider::Database::Mysql
  connection conn
  database_name node[:trove][:db][:database]
  action :create
end

# create user
database_user node[:trove][:db][:user] do
  provider ::Chef::Provider::Database::MysqlUser
  connection conn
  password node[:trove][:db][:password]
  action :create
end

# grant privs to user
database_user node[:trove][:db][:user] do
  provider ::Chef::Provider::Database::MysqlUser
  connection conn
  password node[:trove][:db][:password]
  database_name node[:trove][:db][:database]
  host "%"
  privileges [:all]
  action :grant
end
