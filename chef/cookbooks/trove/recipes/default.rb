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

node.set['openstack']['database_service']['verbose'] = node[:trove][:verbose]
node.set['openstack']['database_service']['debug'] = node[:trove][:debug]
node.set['openstack']['database_service']['volume_support'] = node[:trove][:volume_support]

[['keystone-server', 'identity-api'],
 ['keystone-server', 'identity-admin'],
 ['nova-multi-controller', 'compute-api'],
 ['cinder-controller', 'volume-api'],
 ['swift-proxy', 'object-storage-api']
].each do |comp, endpoint|
  instance = get_instance("roles:#{comp}")
  Chef::Log.info("Found #{comp} instance on #{instance}.")
  node.set_unless['openstack']['endpoints'][endpoint] = {}
  node.set['openstack']['endpoints'][endpoint]['host'] = instance[:fqdn]
  node.set['openstack']['endpoints'][endpoint]['scheme'] = instance[:protocol]
  node.set['openstack']['endpoints'][endpoint]['port'] = instance[:service_port]
end

node.set_unless['openstack']['endpoints']['database_service-api'] = {}
node.set['openstack']['endpoints']['database_service-api']['host'] = node[:fqdn]

rabbitmq = get_instance('roles:rabbitmq-server')
Chef::Log.info("Found rabbitmq server on #{rabbitmq}.")
node.set['openstack']['mq']['service_type'] = 'rabbitmq'
node.set['openstack']['mq']['database_service']['rabbit']['host'] = rabbitmq[:fqdn]
node.set['openstack']['mq']['database_service']['rabbit']['use_ssl'] = (rabbitmq[:protocol] == 'https')
node.set['openstack']['mq']['database_service']['rabbit']['port'] = rabbitmq[:service_port]

# XXX mysql configuration
# this part should go away once trove supports postgresl
['mysql', 'python-mysql'].each do |pkg|
  package pkg
end

service 'mysql' do
  action :start
end

node.set['openstack']['db']['trove']['db_type'] = 'mysql'

# copied from openstack-common/database/db_create_with_user
conn = {
    :host => '127.0.0.1',
    :port => 3306,
    :username => 'root',
  }

database 'create trove database' do
  provider ::Chef::Provider::Database::Mysql
  connection conn
  database_name 'trove'
  action :create
end

# create user
database_user 'trove' do
  provider ::Chef::Provider::Database::MysqlUser
  connection conn
  password 'openstack-database_service'
  action :create
end

# grant privs to user
database_user 'trove' do
  provider ::Chef::Provider::Database::MysqlUser
  connection conn
  password 'openstack-database_service'
  database_name 'trove'
  host '%'
  privileges [:all]
  action :grant
end

include_recipe 'openstack-database_service::identity_registration'
include_recipe 'openstack-database_service::api'
include_recipe 'openstack-database_service::conductor'
include_recipe 'openstack-database_service::taskmanager'
