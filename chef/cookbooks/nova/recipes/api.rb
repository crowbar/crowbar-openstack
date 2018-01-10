#
# Cookbook Name:: nova
# Recipe:: api
#
# Copyright 2010, Opscode, Inc.
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

include_recipe "nova::config"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

use_crowbar_pacemaker_service = node[:nova][:ha][:enabled] &&
  node[:pacemaker][:clone_stateless_services]

nova_package "api" do
  use_pacemaker_provider use_crowbar_pacemaker_service
end

api_ha_enabled = node[:nova][:ha][:enabled]
admin_api_host = CrowbarHelper.get_host_for_admin_url(node, api_ha_enabled)
public_api_host = CrowbarHelper.get_host_for_public_url(node, node[:nova][:ssl][:enabled], api_ha_enabled)
api_port = node[:nova][:ports][:api]

api_protocol = node[:nova][:ssl][:enabled] ? "https" : "http"

crowbar_pacemaker_sync_mark "wait-nova_register" if api_ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "nova api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register nova user" do
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

keystone_register "give nova user access" do
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

keystone_register "register nova service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "nova"
  service_type "compute"
  service_description "Openstack Nova Service"
  action :add_service
end

keystone_register "register nova_legacy service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "nova_legacy"
  service_type "compute_legacy"
  service_description "Openstack Nova Compute Service (Legacy 2.0)"
  action :add_service
end

keystone_register "register nova endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "nova"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{api_protocol}://"\
                     "#{public_api_host}:#{api_port}/v2.1/$(project_id)s"
  endpoint_adminURL "#{api_protocol}://"\
                    "#{admin_api_host}:#{api_port}/v2.1/$(project_id)s"
  endpoint_internalURL "#{api_protocol}://"\
                       "#{admin_api_host}:#{api_port}/v2.1/$(project_id)s"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

keystone_register "register nova_legacy endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "nova_legacy"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{api_protocol}://"\
                     "#{public_api_host}:#{api_port}/v2/$(project_id)s"
  endpoint_adminURL "#{api_protocol}://"\
                    "#{admin_api_host}:#{api_port}/v2/$(project_id)s"
  endpoint_internalURL "#{api_protocol}://"\
                       "#{admin_api_host}:#{api_port}/v2/$(project_id)s"
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-nova_register" if api_ha_enabled

service = "openstack-nova-api"
if node[:nova][:resource_limits] && node[:nova][:resource_limits][service]
  limits = node[:nova][:resource_limits][service]
  action = limits.values.any? ? :create : :delete
  utils_systemd_override_limits "Resource limits for #{service}" do
    service_name service
    limits limits
    action action
  end
end
