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

node.set["openstack"]["database"]["verbose"] = node[:trove][:verbose]
node.set["openstack"]["database"]["debug"] = node[:trove][:debug]
node.set["openstack"]["database"]["volume_support"] = node[:trove][:volume_support]
# we need this in order for nova file injection to work for trove
node.set["openstack"]["database"]["use_nova_server_config_drive"] = true

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
node.set_unless["openstack"]["endpoints"]["identity-api"] = {}
node["openstack"]["endpoints"]["identity-api"]["host"] = keystone_settings["internal_url_host"]
node["openstack"]["endpoints"]["identity-api"]["scheme"] = keystone_settings["protocol"]
node["openstack"]["endpoints"]["identity-api"]["port"] = keystone_settings["service_port"]

node.set_unless["openstack"]["endpoints"]["identity-admin"] = {}
node["openstack"]["endpoints"]["identity-admin"]["host"] = keystone_settings["internal_url_host"]
node["openstack"]["endpoints"]["identity-admin"]["scheme"] = keystone_settings["protocol"]
node["openstack"]["endpoints"]["identity-admin"]["port"] = keystone_settings["admin_port"]

nova_multi_controller = get_instance("roles:nova-controller")
Chef::Log.info("Found nova-controller instance on #{nova_multi_controller}.")
nova_ha_enabled = nova_multi_controller[:nova][:ha][:enabled]
node.set_unless["openstack"]["endpoints"]["compute-api"] = {}
node["openstack"]["endpoints"]["compute-api"]["host"] = CrowbarHelper.get_host_for_admin_url(nova_multi_controller, nova_ha_enabled)
node["openstack"]["endpoints"]["compute-api"]["scheme"] = nova_multi_controller["nova"]["ssl"]["enabled"] ? "https" : "http"
node["openstack"]["endpoints"]["compute-api"]["port"] = nova_multi_controller["nova"]["ports"]["api"]

cinder_controller = get_instance("roles:cinder-controller")
Chef::Log.info("Found cinder-controller instance on #{cinder_controller}.")
cinder_ha_enabled = cinder_controller[:cinder][:ha][:enabled]
node.set_unless["openstack"]["endpoints"]["block-storage-api"] = {}
node["openstack"]["endpoints"]["block-storage-api"]["host"] = CrowbarHelper.get_host_for_admin_url(cinder_controller, cinder_ha_enabled)
node["openstack"]["endpoints"]["block-storage-api"]["scheme"] = cinder_controller["cinder"]["api"]["protocol"]
node["openstack"]["endpoints"]["block-storage-api"]["port"] = cinder_controller["cinder"]["api"]["bind_port"]

swift_proxy = get_instance("roles:swift-proxy")
if swift_proxy  # swift is optional
  Chef::Log.info("Found swift-proxy instance on #{swift_proxy}.")
  swift_ha_enabled = swift_proxy[:swift][:ha][:enabled]
  node.set_unless["openstack"]["endpoints"]["object-storage-api"] = {}
  node["openstack"]["endpoints"]["object-storage-api"]["host"] = CrowbarHelper.get_host_for_admin_url(swift_proxy, swift_ha_enabled)
  node["openstack"]["endpoints"]["object-storage-api"]["scheme"] = swift_proxy["swift"]["ssl"]["enabled"] ? "https" : "http"
  node["openstack"]["endpoints"]["object-storage-api"]["port"] = swift_proxy["swift"]["ports"]["proxy"]
else
  Chef::Log.info("Did not find a swift-proxy instance.")
end

# talking to nova via the novaclient, this should be an admin user in
# the keystone config (see the attributes in trove-taskmanager.conf and
# others)
node.set["openstack"]["database"]["nova_proxy_user"] = keystone_settings["admin_user"]
node.set["openstack"]["database"]["nova_proxy_password"] = keystone_settings["admin_password"]
node.set["openstack"]["database"]["nova_proxy_tenant"] = keystone_settings["admin_tenant"]

node.set["openstack"]["use_databags"] = false
node.set["openstack"]["secret"]["openstack_identity_bootstrap_token"] = {token: keystone_settings["admin_token"] }
node.set["openstack"]["secret"]["database"]["db"] = node[:trove][:db][:password]
node.set["openstack"]["secret"]["database"]["service"] = keystone_settings["service_password"]
node.set["openstack"]["database"]["service_user"] = keystone_settings["service_user"]

node.set_unless["openstack"]["endpoints"]["database-api"] = {}
node.set["openstack"]["endpoints"]["database-api"]["host"] = node["fqdn"]
node.set["openstack"]["endpoints"]["database-api"]["bind-host"] = node["fqdn"]

rabbit_settings = fetch_rabbitmq_settings
rabbitmq = get_instance("roles:rabbitmq-server")[:rabbitmq]
node.set["openstack"]["mq"]["service_type"] = "rabbitmq"
node.set["openstack"]["mq"]["database"]["rabbit"]["host"] = rabbit_settings[:address]
node.set["openstack"]["mq"]["database"]["rabbit"]["port"] = rabbit_settings[:port] if rabbitmq[:port]
node.set["openstack"]["mq"]["database"]["rabbit"]["userid"] = rabbitmq[:trove][:user]
node.set["openstack"]["mq"]["database"]["rabbit"]["vhost"] = rabbitmq[:trove][:vhost]
node.set["openstack"]["secret"][rabbitmq[:trove][:user]]["user"] = rabbitmq[:trove][:password]

node.set["openstack"]["insecure"] = keystone_settings["insecure"]
node.set["openstack"]["identity"]["insecure"] = keystone_settings["insecure"]
node.set["openstack"]["compute"]["insecure"] = nova_multi_controller[:nova][:ssl][:insecure]
node.set["openstack"]["block-storage"]["insecure"] = cinder_controller[:cinder][:ssl][:insecure]
node.set["openstack"]["object-storage"]["insecure"] = swift_proxy[:swift][:ssl][:insecure]
node.set["openstack"]["database"]["insecure"] = keystone_settings["insecure"]
node.set["openstack"]["region"] = keystone_settings["endpoint_region"]
node.set["openstack"]["database"]["region"] = keystone_settings["endpoint_region"]
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

include_recipe "openstack-database::identity_registration"
include_recipe "openstack-database::api"
include_recipe "openstack-database::conductor"
include_recipe "openstack-database::taskmanager"
