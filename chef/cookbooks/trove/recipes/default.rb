#
# Cookbook Name:: trove
# Recipe:: default
#
# Copyright 2014, SUSE Linux GmbH
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

class ::Chef::Recipe
  include ::Openstack
end

# TODO developer mode is set so we don't have to handle data bags yet
node.set[:openstack][:developer_mode] = true
node.set["openstack"]["database_service"]["verbose"] = node[:trove][:verbose]

[['keystone', 'identity-api'],
  ['nova', 'compute-api'],
  ['cinder', 'volume-api'],
  ['swift', 'object-storage-api']
].each do |comp, endpoint|
  instance = get_instance(:node, "recipes:#{comp}\\:\\:server")
  Chef::Log.info("Found #{comp} server on #{instance}.")
  node.set_unless["openstack"]["endpoints"][endpoint] = {}
  node.set["openstack"]["endpoints"][endpoint]["host"] = instance[:fqdn]
  node.set["openstack"]["endpoints"][endpoint]["scheme"] = instance[:protocol]
  node.set["openstack"]["endpoints"][endpoint]["port"] = instance[:service_port]
end

# XXX mysql configuration
# this part should go away once trove supports postgresl
['mysql', 'python-mysql'].each do |pkg|
  package pkg
end

service "mysql" do
  action :start
end

node.set["openstack"]["db"]["trove"]["db_type"] = "mysql"

# copied from openstack-common/database/db_create_with_user
conn = {
    :host => '127.0.0.1',
    :port => 3306,
    :username => 'root',
  }

database "create trove database" do
  provider ::Chef::Provider::Database::Mysql
  connection conn
  database_name "trove"
  action :create
end

# create user
database_user "trove" do
  provider ::Chef::Provider::Database::MysqlUser
  connection conn
  password "openstack-database_service"
  action :create
end

# grant privs to user
database_user "trove" do
  provider ::Chef::Provider::Database::MysqlUser
  connection conn
  password "openstack-database_service"
  database_name "trove"
  host '%'
  privileges [:all]
  action :grant
end

# XXX enable the identity_registration recipe instead of setting up
# mysql manually above
# include_recipe "openstack-database_service::identity_registration"
include_recipe "openstack-database_service::api"
include_recipe "openstack-database_service::conductor"
include_recipe "openstack-database_service::taskmanager"
