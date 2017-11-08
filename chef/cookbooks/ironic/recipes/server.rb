# frozen_string_literal: true
# Copyright 2016 SUSE
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

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# Create the Ironic Database
database "create #{node[:ironic][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:ironic][:db][:database]
  provider db_settings[:provider]
  action :create
end

database_user "create ironic database user" do
  host "%"
  connection db_settings[:connection]
  username node[:ironic][:db][:user]
  password node[:ironic][:db][:password]
  provider db_settings[:user_provider]
  action :create
end

database_user "grant database access for ironic database user" do
  connection db_settings[:connection]
  username node[:ironic][:db][:user]
  password node[:ironic][:db][:password]
  database_name node[:ironic][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
end

node[:ironic][:platform][:packages].each do |p|
  package p
end

node[:ironic][:enabled_drivers].each do |d|
  driver_dependencies = node[:ironic][:platform][:driver_dependencies][d] || []
  driver_dependencies.each do |p|
    package p
  end
end

ironic_net_ip = Barclamp::Inventory.get_network_by_type(node, "ironic").address

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

auth_version = "v2.0"

glance = node_search_with_cache("roles:glance-server").first
raise "No glance-server found. Can not configure ironic." if glance.nil?
glance_settings = { protocol: glance[:glance][:api][:protocol],
                    host: CrowbarHelper.get_host_for_admin_url(
                      glance, glance[:glance][:ha][:enabled]
                    ),
                    port: glance[:glance][:api][:bind_port] }

neutron = node_search_with_cache("roles:neutron-server").first
raise "No neutron-server found. Can not configure ironic." if neutron.nil?
neutron_settings = { protocol: neutron[:neutron][:api][:protocol],
                     host: CrowbarHelper.get_host_for_admin_url(
                       neutron, neutron[:neutron][:ha][:server][:enabled]
                     ),
                     port: neutron[:neutron][:api][:service_port] }

api_port = node[:ironic][:api][:port]
api_protocol = node[:ironic][:api][:protocol]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node)
my_public_host = CrowbarHelper.get_host_for_public_url(node, false)

db_connection = fetch_database_connection_string(node[:ironic][:db])

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "ironic wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register ironic service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "ironic"
  service_type "baremetal"
  service_description "Ironic baremetal provisioning service"
  action :add_service
end

public_endpoint = "#{api_protocol}://#{my_public_host}:#{api_port}"
admin_endpoint = "#{api_protocol}://#{my_admin_host}:#{api_port}"
internal_endpoint = admin_endpoint

keystone_register "register ironic endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "ironic"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL public_endpoint
  endpoint_adminURL admin_endpoint
  endpoint_internalURL internal_endpoint
  action :add_endpoint_template
end

keystone_register "register ironic user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give ironic user admin role in service tenant" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

template node[:ironic][:config_file] do
  source "ironic.conf.erb"
  owner "root"
  group node[:ironic][:group]
  mode "0640"
  variables(
    lazy {
      {
        automated_clean: node[:ironic][:automated_clean],
        drivers: node[:ironic][:enabled_drivers],
        debug: node[:ironic][:debug],
        rabbit_settings: fetch_rabbitmq_settings,
        keystone_settings: keystone_settings,
        glance_settings: glance_settings,
        swift_settings: IronicHelper.swift_settings(node, glance),
        neutron_settings: neutron_settings,
        database_connection: db_connection,
        ironic_net_id: IronicHelper.ironic_net_id(keystone_settings),
        ironic_ip: ironic_net_ip,
        tftp_ip: ironic_net_ip,
        tftproot: node[:ironic][:tftproot],
        public_endpoint: public_endpoint,
        api_port: api_port,
        auth_version: auth_version
      }
    }
  )
end

service "ironic-api" do
  service_name node[:ironic][:api][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:ironic][:config_file])
end
utils_systemd_service_restart "ironic-api" do
  action :enable
end

service "ironic-conductor" do
  service_name node[:ironic][:conductor][:service_name]
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:ironic][:config_file])
end
utils_systemd_service_restart "ironic-conductor" do
  action :enable
end

execute "ironic-dbsync" do
  user node[:ironic][:user]
  group node[:ironic][:group]
  command "ironic-dbsync"
  # We only do the sync the first time
  only_if { !node[:ironic][:db_synced] }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for ironic-dbsync" do
  block do
    node.set[:ironic][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[ironic-dbsync]", :immediately
end

node.save
