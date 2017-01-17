#
# Copyright 2017 Fujitsu LIMITED
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
# limitation.

monasca_pkgs = node[:monasca][:platform][:packages]
monasca_project = node[:monasca][:service_tenant]
monasca_roles = node[:monasca][:service_roles]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

register_auth_hash = {
  user: keystone_settings["admin_user"],
  password: keystone_settings["admin_password"],
  tenant: keystone_settings["admin_tenant"]
}

monasca_pkgs.each do |pkg|
  package pkg
end

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

### recipes agents specific settings
### single credentials all metrics & logs agents
agents_settings = []

# once agent is ready, uncomment following lines
# if node["roles"].include?("monasca-agent")
#   agents_settings.push(node[:monasca][:agent][:keystone])
# end
if node["roles"].include?("monasca-log-agent")
  la_keystone = node[:monasca][:log_agent][:keystone]
  agents_settings.push(la_keystone)
end

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
### recipes specific keystone handling
