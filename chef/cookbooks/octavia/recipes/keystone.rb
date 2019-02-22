# Copyright 2019 SUSE Linux GmbH.
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
keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

octavia_port = node[:octavia][:api][:port]
octavia_protocol = "http" # TODO: node[:octavia][:api][:protocol]

ha_enabled = false # TODO: node[:octavia][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:octavia][:api][:protocol] == "https", ha_enabled
)

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

crowbar_pacemaker_sync_mark "wait-octavia_register" if ha_enabled

keystone_register "octavia api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register octavia user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  project_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give octavia user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  project_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

keystone_register "register octavia service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "octavia"
  service_type "data-processing"
  service_description "Openstack octavia - Data Processing"
  action :add_service
end

keystone_register "register octavia endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "octavia"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{octavia_protocol}://#{my_public_host}:#{octavia_port}/v1.1/%(tenant_id)s"
  endpoint_adminURL "#{octavia_protocol}://#{my_admin_host}:#{octavia_port}/v1.1/%(tenant_id)s"
  endpoint_internalURL "#{octavia_protocol}://#{my_admin_host}:#{octavia_port}/v1.1/%(tenant_id)s"
  action :add_endpoint
end

crowbar_pacemaker_sync_mark "create-octavia_register" if ha_enabled
