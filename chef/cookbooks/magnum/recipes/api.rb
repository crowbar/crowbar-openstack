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
# Cookbook Name:: magnum
# Recipe:: api
#

include_recipe "#{@cookbook_name}::common"
include_recipe "#{@cookbook_name}::sql"

keystone_settings = KeystoneHelper.keystone_settings(node, :magnum)

magnum_port = node[:magnum][:api][:bind_port]
magnum_protocol = node[:magnum][:api][:protocol]

ha_enabled = node[:manila][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:magnum][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-magnum_register"

keystone_register "magnum api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  action :wakeup
end

keystone_register "register magnum user" do
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

keystone_register "give magnum user access" do
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

keystone_register "register magnum service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  service_name "magnum"
  service_type "containers"
  service_description "Openstack Magnum - Containers as a Service"
  action :add_service
end

keystone_register "register magnum endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  endpoint_service "magnum"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{magnum_protocol}://"\
                     "#{my_public_host}:#{magnum_port}/v1/$(tenant_id)s"
  endpoint_adminURL "#{magnum_protocol}://"\
                    "#{my_admin_host}:#{magnum_port}/v1/$(tenant_id)s"
  endpoint_internalURL "#{magnum_protocol}://"\
                       "#{my_admin_host}:#{magnum_port}/v1/$(tenant_id)s"
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-magnum_register"

magnum_service "api" do
  use_pacemaker_provider ha_enabled
end
