# Copyright 2017 SUSE Linux GmbH
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
# Cookbook Name:: murano
# Recipe:: api
#

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

murano_port = node[:murano][:api][:bind_port]
murano_protocol = node[:murano][:api][:protocol]

ha_enabled = node[:murano][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:murano][:api][:protocol] == "https", ha_enabled
)

register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

crowbar_pacemaker_sync_mark "wait-murano_register"

keystone_register "murano api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register murano user" do
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

keystone_register "give murano user access" do
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

keystone_register "register murano service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "murano"
  service_type "application-catalog"
  service_description "Openstack murano - Application Catalog"
  action :add_service
end

keystone_register "register murano endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "murano"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{murano_protocol}://#{my_public_host}:#{murano_port}"
  endpoint_adminURL "#{murano_protocol}://#{my_admin_host}:#{murano_port}"
  endpoint_internalURL "#{murano_protocol}://#{my_admin_host}:#{murano_port}"
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-murano_register"

murano_service "api"

# Load the core app into murano, needed for everything
execute "murano-manage core package" do
  command "murano-manage import-package #{node[:murano][:core_package_location]}"
  user node[:murano][:user]
  group node[:murano][:group]
  only_if { File.exist?(node[:murano][:core_package_location]) }
end
