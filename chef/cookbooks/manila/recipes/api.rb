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

include_recipe "#{@cookbook_name}::common"
include_recipe "#{@cookbook_name}::sql"

keystone_settings = KeystoneHelper.keystone_settings(node, :manila)

manila_port = node[:manila][:api][:bind_port]
manila_protocol = node[:manila][:api][:protocol]

ha_enabled = node[:manila][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:manila][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-manila_register"

keystone_register "manila api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  action :wakeup
end

keystone_register "register manila user" do
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

keystone_register "give manila user access" do
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

keystone_register "register manila service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  service_name "manila"
  service_type "share"
  service_description "Openstack Manila shared filesystem service"
  action :add_service
end

keystone_register "register manila endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  endpoint_service "manila"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{manila_protocol}://"\
                     "#{my_public_host}:#{manila_port}/v1/$(tenant_id)s"
  endpoint_adminURL "#{manila_protocol}://"\
                    "#{my_admin_host}:#{manila_port}/v1/$(tenant_id)s"
  endpoint_internalURL "#{manila_protocol}://"\
                       "#{my_admin_host}:#{manila_port}/v1/$(tenant_id)s"
  #  endpoint_global true
  #  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-manila_register"

manila_service "api" do
  use_pacemaker_provider ha_enabled
end

# NOTE(toabctl): We modified the upstream api-paste.ini and the manila.conf.erb
# to use keystonemiddleware and a [keystone_auth] section in manila.conf instead
# of the parameters from api-paste.ini. So the api-paste.ini is different than
# in the version from the package.
# TODO(toabctl): Remove this in Kilo because the api-paste.ini then no longer
# contains the auth parameters
cookbook_file "api-paste.ini" do
  path "/etc/manila/api-paste.ini"
  owner "root"
  group node[:manila][:group]
  mode "0640"
  action :create
  notifies :restart, "service[manila-api]"
end
