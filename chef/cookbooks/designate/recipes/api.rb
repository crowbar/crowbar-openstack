# Copyright 2018 SUSE Linux GmbH
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
# Cookbook Name:: designate
# Recipe:: api
#

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

designate_port = node[:designate][:api][:bind_port]
designate_protocol = node[:designate][:api][:protocol]

ha_enabled = node[:designate][:ha][:enabled]

if node[:designate][:api][:protocol] == "https"
  ssl_setup "setting up ssl for designate" do
    generate_certs node[:designate][:ssl][:generate_certs]
    certfile node[:designate][:ssl][:certfile]
    keyfile node[:designate][:ssl][:keyfile]
    group node[:designate][:group]
    fqdn node[:fqdn]
    cert_required node[:designate][:ssl][:cert_required]
    ca_certs node[:designate][:ssl][:ca_certs]
  end
end

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:designate][:api][:protocol] == "https", ha_enabled
)

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

crowbar_pacemaker_sync_mark "wait-designate_register" if ha_enabled

keystone_register "designate api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register designate user" do
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

keystone_register "give designate user access" do
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

keystone_register "register designate service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "designate"
  service_type "dns"
  service_description "Designate DNS Service"
  action :add_service
end

keystone_register "register designate endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "designate"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{designate_protocol}://#{my_public_host}:#{designate_port}/"
  endpoint_adminURL "#{designate_protocol}://#{my_admin_host}:#{designate_port}/"
  endpoint_internalURL "#{designate_protocol}://#{my_admin_host}:#{designate_port}/"
  action :add_endpoint
end

crowbar_pacemaker_sync_mark "create-designate_register" if ha_enabled

designate_service "central"
designate_service "api"
designate_service "producer" unless ha_enabled
