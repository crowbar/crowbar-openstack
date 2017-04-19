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

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

keystone_register "monasca api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register monasca api user" do
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

keystone_register "give monasca api user access" do
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

keystone_register "register monasca api service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "monasca"
  service_type "monitoring"
  service_description "Monasca monitoring service"
  action :add_service
end

keystone_register "register monasca api endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "monasca"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL MonascaHelper.api_public_url(node)
  endpoint_adminURL MonascaHelper.api_admin_url(node)
  endpoint_internalURL MonascaHelper.api_internal_url(node)
  action :add_endpoint_template
end

monasca_project = node[:monasca][:service_tenant]
monasca_roles = node[:monasca][:service_roles]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

keystone_register "monasca:common wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "monasca:common create tenant #{monasca_project} for monasca" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  tenant_name monasca_project
  action :add_tenant
end

monasca_roles.each do |role|
  keystone_register "monasca:common register #{role} role in #{monasca_project} tenant" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    role_name role
    action :add_role
  end
end

agents_settings = []

agents_settings.push(node[:monasca][:metric_agent][:keystone])
la_keystone = node[:monasca][:log_agent][:keystone]
agents_settings.push(la_keystone)

unless agents_settings.empty?
  agents_settings.each do |as|

    keystone_register "monasca:common #{as["service_user"]} in #{as["service_tenant"]} project" do
      protocol keystone_settings["protocol"]
      insecure keystone_settings["insecure"]
      host keystone_settings["internal_url_host"]
      port keystone_settings["admin_port"]
      auth register_auth_hash
      user_name as["service_user"]
      user_password as["service_password"]
      tenant_name as["service_tenant"]
      action :add_user
    end

    keystone_register "monasca:common #{as["service_user"]} assign role #{as["service_role"]}" do
      protocol keystone_settings["protocol"]
      insecure keystone_settings["insecure"]
      host keystone_settings["internal_url_host"]
      port keystone_settings["admin_port"]
      auth register_auth_hash
      user_name as["service_user"]
      tenant_name as["service_tenant"]
      role_name as["service_role"]
      action :add_access
    end

  end
end
