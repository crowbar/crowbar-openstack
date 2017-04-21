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
# Cookbook Name:: sahara
# Recipe:: api
#

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

sahara_port = node[:sahara][:api][:bind_port]
sahara_protocol = node[:sahara][:api][:protocol]

ha_enabled = node[:sahara][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:sahara][:api][:protocol] == "https", ha_enabled
)

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

crowbar_pacemaker_sync_mark "wait-sahara_register" if ha_enabled

keystone_register "sahara api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register sahara user" do
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

keystone_register "give sahara user access" do
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

keystone_register "register sahara service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "sahara"
  service_type "data-processing"
  service_description "Openstack Sahara - Data Processing"
  action :add_service
end

keystone_register "register sahara endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "sahara"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{sahara_protocol}://#{my_public_host}:#{sahara_port}/v1.1/%(tenant_id)s"
  endpoint_adminURL "#{sahara_protocol}://#{my_admin_host}:#{sahara_port}/v1.1/%(tenant_id)s"
  endpoint_internalURL "#{sahara_protocol}://#{my_admin_host}:#{sahara_port}/v1.1/%(tenant_id)s"
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-sahara_register" if ha_enabled

sahara_service "api"
