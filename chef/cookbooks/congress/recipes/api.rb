#
# Copyright 2015 SUSE Linux GmbH
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
# Cookbook Name:: congress
# Recipe:: api
#

include_recipe "#{@cookbook_name}::common"
include_recipe "#{@cookbook_name}::sql"

keystone_settings = KeystoneHelper.keystone_settings(node, :congress)

congress_port = node[:congress][:api][:bind_port]
congress_protocol = node[:congress][:api][:protocol]

ha_enabled = node[:congress][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:congress][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-congress_register"

keystone_register "congress api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  action :wakeup
end

keystone_register "register congress user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give congress user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

keystone_register "register congress service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  service_name "congress"
  service_type "policy"
  service_description "Openstack Congress Policy As A Service"
  action :add_service
end

keystone_register "register congress endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  endpoint_service "congress"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{congress_protocol}://"\
                     "#{my_public_host}:#{congress_port}/v1/$(tenant_id)s"
  endpoint_adminURL "#{congress_protocol}://"\
                    "#{my_admin_host}:#{congress_port}/v1/$(tenant_id)s"
  endpoint_internalURL "#{congress_protocol}://"\
                       "#{my_admin_host}:#{congress_port}/v1/$(tenant_id)s"
  #  endpoint_global true
  #  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-congress_register"

congress_service "api" do
  use_pacemaker_provider ha_enabled
end
