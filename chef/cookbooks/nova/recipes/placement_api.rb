#
# Cookbook Name:: nova
# Recipe:: placement_api
#
# Copyright 2017, SUSE Linux GmbH
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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "nova::config"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

package "openstack-nova-placement-api"

api_ha_enabled = node[:nova][:ha][:enabled]
admin_api_host = CrowbarHelper.get_host_for_admin_url(node, api_ha_enabled)
public_api_host = CrowbarHelper.get_host_for_public_url(
  node, node[:nova][:ssl][:enabled], api_ha_enabled
)
api_port = node[:nova][:ports][:placement_api]

api_protocol = node[:nova][:ssl][:enabled] ? "https" : "http"

crowbar_pacemaker_sync_mark "wait-nova-placement_register" if api_ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "register placement user '#{node["nova"]["placement_service_user"]}'" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name node["nova"]["placement_service_user"]
  user_password node["nova"]["placement_service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give placement user '#{node["nova"]["placement_service_user"]}' access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name node["nova"]["placement_service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

keystone_register "register placement service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "placement"
  service_type "placement"
  service_description "Openstack Placement Service"
  action :add_service
end

keystone_register "register placement endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "placement"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{api_protocol}://#{public_api_host}:#{api_port}"
  endpoint_adminURL "#{api_protocol}://#{admin_api_host}:#{api_port}"
  endpoint_internalURL "#{api_protocol}://#{admin_api_host}:#{api_port}"
  action :add_endpoint_template
end

if node[:nova][:ha][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:nova][:ha][:ports][:placement_api]
else
  bind_host = "0.0.0.0"
  bind_port = node[:nova][:ports][:placement_api]
end

node.normal[:apache][:listen_ports_crowbar] ||= {}
node.normal[:apache][:listen_ports_crowbar][:nova] = { plain: [bind_port] }

crowbar_openstack_wsgi "WSGI entry for nova-placement-api" do
  bind_host bind_host
  bind_port bind_port
  daemon_process "nova-placement-api"
  user node[:nova][:user]
  group node[:nova][:group]
  ssl_enable node[:nova][:ssl][:enabled]
  ssl_certfile node[:nova][:ssl][:certfile]
  ssl_keyfile node[:nova][:ssl][:keyfile]
  if node[:nova][:ssl][:cert_required]
    ssl_cacert node[:nova][:ssl][:ca_certs]
  end
end

apache_site "nova-placement-api.conf" do
  enable true
end

crowbar_pacemaker_sync_mark "create-nova-placement_register" if api_ha_enabled
