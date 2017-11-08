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
# Cookbook Name:: ec2api
# Recipe:: ec2api

package "openstack-ec2-api"
package "openstack-ec2-api-api"
package "openstack-ec2-api-metadata"
package "openstack-ec2-api-s3"

# NOTE: ec2 is deployed via the nova barclamp
ha_enabled  = node[:nova]["ec2-api"][:ha][:enabled]
ssl_enabled = node[:nova]["ec2-api"][:ssl][:enabled]
api_protocol = ssl_enabled ? "https" : "http"
db_settings = fetch_database_settings "nova"
ec2_api_port = node[:nova][:ports][:ec2_api]
ec2_metadata_port = node[:nova][:ports][:ec2_metadata]
if ha_enabled
  bind_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_port_ec2api = node[:nova][:ha][:ports][:ec2_api]
  bind_port_metadata = node[:nova][:ha][:ports][:ec2_metadata]
  bind_port_s3 = node[:nova][:ha][:ports][:ec2_s3]
else
  bind_host = "0.0.0.0"
  bind_port_ec2api = node[:nova][:ports][:ec2_api]
  bind_port_metadata = node[:nova][:ports][:ec2_metadata]
  bind_port_s3 = node[:nova][:ports][:ec2_s3]
end

crowbar_pacemaker_sync_mark "wait-ec2_api_database" if ha_enabled

database_connection = fetch_database_connection_string(node[:nova]["ec2-api"][:db], "nova")

# Create the ec2 Database
database "create #{node[:nova]["ec2-api"][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:nova]["ec2-api"][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:nova]["ec2-api"][:db][:database]
  username node[:nova]["ec2-api"][:db][:user]
  password node[:nova]["ec2-api"][:db][:password]
  host "%"
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:nova]["ec2-api"][:db][:database]
  username node[:nova]["ec2-api"][:db][:user]
  password node[:nova]["ec2-api"][:db][:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-ec2_api_database" if ha_enabled

rabbit_settings = fetch_rabbitmq_settings "nova"
keystone_settings = KeystoneHelper.keystone_settings(node, "nova")

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, ssl_enabled, ha_enabled)

crowbar_pacemaker_sync_mark "wait-ec2_api_register" if ha_enabled

keystone_register "register ec2 user" do
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

keystone_register "give ec2 user access" do
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

# Create ec2-api service
keystone_register "register ec2-api service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "ec2-api"
  service_type "ec2"
  service_description "EC2 Compatibility Layer"
  action :add_service
end

keystone_register "register ec2-api endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "ec2-api"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{api_protocol}://#{my_public_host}:#{ec2_api_port}"
  endpoint_adminURL "#{api_protocol}://#{my_admin_host}:#{ec2_api_port}"
  endpoint_internalURL "#{api_protocol}://#{my_admin_host}:#{ec2_api_port}"
  action :add_endpoint_template
end

# Create ec2-metadata service
keystone_register "register ec2-metadata service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "ec2-metadata"
  service_type "ec2"
  service_description "EC2 Compatibility Layer"
  action :add_service
end

keystone_register "register ec2-metadata endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "ec2-metadata"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{api_protocol}://#{my_public_host}:#{ec2_metadata_port}"
  endpoint_adminURL "#{api_protocol}://#{my_admin_host}:#{ec2_metadata_port}"
  endpoint_internalURL "#{api_protocol}://#{my_admin_host}:#{ec2_metadata_port}"
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-ec2_api_register" if ha_enabled

# ec2-api ssl
if node[:nova]["ec2-api"][:ssl][:enabled]
  ssl_setup "setting up ssl for ec2-api" do
    generate_certs node[:nova]["ec2-api"][:ssl][:generate_certs]
    certfile node[:nova]["ec2-api"][:ssl][:certfile]
    keyfile node[:nova]["ec2-api"][:ssl][:keyfile]
    group node[:nova]["ec2-api"][:group]
    fqdn node[:fqdn]
    cert_required node[:nova]["ec2-api"][:ssl][:cert_required]
    ca_certs node[:nova]["ec2-api"][:ssl][:ca_cert]
  end
end

template node[:nova]["ec2-api"][:config_file] do
  source "ec2api.conf.erb"
  owner "root"
  group node[:nova]["ec2-api"][:group]
  mode 0o640
  variables(
    debug: node[:nova][:debug],
    database_connection: database_connection,
    rabbit_settings: rabbit_settings,
    keystone_settings: keystone_settings,
    bind_host: bind_host,
    bind_port_ec2api: bind_port_ec2api,
    bind_port_metadata: bind_port_metadata,
    bind_port_s3: bind_port_s3,
  )
end

use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

service "openstack-ec2-api-api" do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:nova]["ec2-api"][:config_file])
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "openstack-ec2-api-api" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "openstack-ec2-api-metadata" do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:nova]["ec2-api"][:config_file])
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "openstack-ec2-api-metadata" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "openstack-ec2-api-s3" do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:nova]["ec2-api"][:config_file])
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "openstack-ec2-api-s3" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

if ha_enabled
  include_recipe "ec2-api::ec2api_ha"
end
