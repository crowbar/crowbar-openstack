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
# Cookbook Name:: manila
# Recipe:: api
#

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "#{@cookbook_name}::common"
include_recipe "#{@cookbook_name}::sql"

package "openstack-manila-api"

keystone_settings = KeystoneHelper.keystone_settings(node, :manila)

manila_port = node[:manila][:api][:bind_port]
manila_protocol = node[:manila][:api][:protocol]

ha_enabled = node[:manila][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:manila][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-manila_register"

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

keystone_register "manila api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register manila user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  project_name keystone_settings["service_tenant"]
  action :add_user
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "give manila user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  project_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register manila service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "manila"
  service_type "share"
  service_description "Openstack Manila shared filesystem service"
  action :add_service
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register manila endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "manila"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{manila_protocol}://"\
                     "#{my_public_host}:#{manila_port}/v1/$(project_id)s"
  endpoint_adminURL "#{manila_protocol}://"\
                    "#{my_admin_host}:#{manila_port}/v1/$(project_id)s"
  endpoint_internalURL "#{manila_protocol}://"\
                       "#{my_admin_host}:#{manila_port}/v1/$(project_id)s"
  action :add_endpoint
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# v2 API is new since Liberty
keystone_register "register manila service v2" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "manilav2"
  service_type "sharev2"
  service_description "Openstack Manila shared filesystem service V2"
  action :add_service
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

keystone_register "register manila endpoint v2" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "manilav2"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{manila_protocol}://"\
                     "#{my_public_host}:#{manila_port}/v2/$(project_id)s"
  endpoint_adminURL "#{manila_protocol}://"\
                    "#{my_admin_host}:#{manila_port}/v2/$(project_id)s"
  endpoint_internalURL "#{manila_protocol}://"\
                       "#{my_admin_host}:#{manila_port}/v2/$(project_id)s"
  action :add_endpoint
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-manila_register"

service "manila-api" do
  service_name "openstack-manila-#{params[:name]}" if %w(rhel suse).include? node[:platform_family]
  supports status: true, restart: true
  action [:disable, :stop]
  # allow to fail here because there may not be a service
  ignore_failure true
end

ssl_enabled = node[:manila][:api][:protocol] == "https"

if node[:manila][:ha][:enabled]
  admin_address = Barclamp::Inventory.get_network_by_type(node, "admin").address
  manila_bind_host = admin_address
  manila_port = node[:manila][:ha][:ports][:api]
else
  manila_bind_host = "0.0.0.0"
end

crowbar_openstack_wsgi "WSGI entry for manila-api" do
  bind_host manila_bind_host
  bind_port manila_port
  daemon_process "manila-api"
  script_alias "/usr/bin/manila-wsgi"
  user node[:manila][:user]
  group node[:manila][:group]
  ssl_enable ssl_enabled
  ssl_certfile node[:manila][:ssl][:certfile]
  ssl_keyfile node[:manila][:ssl][:keyfile]
  if node[:manila][:ssl][:cert_required]
    ssl_cacert node[:manila][:ssl][:ca_certs]
  end
end

apache_site "manila-api.conf" do
  enable true
end
