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

env_filter = " AND keystone_config_environment:keystone-config-#{node[:cinder][:keystone_instance]}"

cinder_path = "/opt/cinder"
venv_path = node[:cinder][:use_virtualenv] ? "#{cinder_path}/.venv" : nil

keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_token = keystone[:keystone][:service][:token]
keystone_service_port = keystone[:keystone][:api][:service_port]
keystone_admin_port = keystone[:keystone][:api][:admin_port]
keystone_service_tenant = keystone[:keystone][:service][:tenant]
keystone_service_user = node[:cinder][:service_user]
keystone_service_password = node[:cinder][:service_password]
cinder_port = node[:cinder][:api][:bind_port]
cinder_protocol = node[:cinder][:api][:protocol]
Chef::Log.info("Keystone server found at #{keystone_address}")

if node[:cinder][:use_gitrepo]
  pfs_and_install_deps "keystone" do
    cookbook "keystone"
    cnode keystone
    path File.join(cinder_path,"keystone")
    virtualenv venv_path
  end
else
  package "python-keystone"
end

public_api_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
admin_api_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

keystone_register "cinder api wakeup keystone" do
  protocol keystone_protocol
  host keystone_address
  port keystone_admin_port
  token keystone_token
  action :wakeup
end

keystone_register "register cinder user" do
  protocol keystone_protocol
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give cinder user access" do
  protocol keystone_protocol
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

keystone_register "register cinder service" do
  protocol keystone_protocol
  host keystone_address
  port keystone_admin_port
  token keystone_token
  service_name "cinder"
  service_type "volume"
  service_description "Openstack Cinder Service"
  action :add_service
end

keystone_register "register cinder endpoint" do
  protocol keystone_protocol
  host keystone_address
  port keystone_admin_port
  token keystone_token
  endpoint_service "cinder"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{cinder_protocol}://#{public_api_ip}:#{cinder_port}/v1/$(tenant_id)s"
  endpoint_adminURL "#{cinder_protocol}://#{admin_api_ip}:#{cinder_port}/v1/$(tenant_id)s"
  endpoint_internalURL "#{cinder_protocol}://#{admin_api_ip}:#{cinder_port}/v1/$(tenant_id)s"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

cinder_service("api")

unless node[:platform] == "suse"
  api_service_name = "cinder-api"
else
  api_service_name = "openstack-cinder-api"
end

template "/etc/cinder/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node[:cinder][:user]
  group "root"
  mode "0640"
  variables(
    :keystone_protocol => keystone_protocol,
    :keystone_ip_address => keystone_address,
    :keystone_admin_token => keystone_token,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
  notifies :restart, resources(:service => api_service_name), :immediately
end

