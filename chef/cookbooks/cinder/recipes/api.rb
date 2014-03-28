#
# Copyright 2012 Dell, Inc.
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
# Cookbook Name:: cinder
# Recipe:: api
#

include_recipe "#{@cookbook_name}::common"
include_recipe "#{@cookbook_name}::sql"

cinder_path = "/opt/cinder"
venv_path = node[:cinder][:use_virtualenv] ? "#{cinder_path}/.venv" : nil

keystone = get_instance('roles:keystone-server')
keystone_settings = KeystoneHelper.keystone_settings(keystone)
keystone_settings['service_user'] = node[:cinder][:service_user]
keystone_settings['service_password'] = node[:cinder][:service_password]
Chef::Log.info("Keystone server found at #{keystone_settings['internal_url_host']}")

cinder_port = node[:cinder][:api][:bind_port]
cinder_protocol = node[:cinder][:api][:protocol]

ha_enabled = node[:cinder][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:cinder][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-cinder_register"

keystone_register "cinder api wakeup keystone" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  action :wakeup
end

keystone_register "register cinder user" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  user_name keystone_settings['service_user']
  user_password keystone_settings['service_password']
  tenant_name keystone_settings['service_tenant']
  action :add_user
end

keystone_register "give cinder user access" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  user_name keystone_settings['service_user']
  tenant_name keystone_settings['service_tenant']
  role_name "admin"
  action :add_access
end

keystone_register "register cinder service" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  service_name "cinder"
  service_type "volume"
  service_description "Openstack Cinder Service"
  action :add_service
end

keystone_register "register cinder endpoint" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  endpoint_service "cinder"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{cinder_protocol}://#{my_public_host}:#{cinder_port}/v1/$(tenant_id)s"
  endpoint_adminURL "#{cinder_protocol}://#{my_admin_host}:#{cinder_port}/v1/$(tenant_id)s"
  endpoint_internalURL "#{cinder_protocol}://#{my_admin_host}:#{cinder_port}/v1/$(tenant_id)s"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-cinder_register"

cinder_service "api" do
  use_pacemaker_provider ha_enabled
end

template "/etc/cinder/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:cinder][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_settings => keystone_settings
  )
  notifies :restart, resources(:service => "cinder-api"), :immediately
end

