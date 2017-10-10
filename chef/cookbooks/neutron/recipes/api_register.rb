# Copyright 2013 Dell, Inc.
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

ha_enabled = node[:neutron][:ha][:server][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:neutron][:api][:protocol] == "https", ha_enabled)

api_port = node["neutron"]["api"]["service_port"]
neutron_protocol = node["neutron"]["api"]["protocol"]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

crowbar_pacemaker_sync_mark "wait-neutron_register" if ha_enabled

keystone_register "neutron api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  action :wakeup
end

keystone_register "register neutron user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  project_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give neutron user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  user_name keystone_settings["service_user"]
  project_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

keystone_register "register neutron service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  service_name "neutron"
  service_type "network"
  service_description "Openstack Neutron Service"
  action :add_service
end

keystone_register "register neutron endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  endpoint_service "neutron"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{neutron_protocol}://#{my_public_host}:#{api_port}/"
  endpoint_adminURL "#{neutron_protocol}://#{my_admin_host}:#{api_port}/"
  endpoint_internalURL "#{neutron_protocol}://#{my_admin_host}:#{api_port}/"
  action :add_endpoint
end

crowbar_pacemaker_sync_mark "create-neutron_register" if ha_enabled
