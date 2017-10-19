#
# Copyright 2012 Dell, Inc.
# Copyright 2014 SUSE Linux GmbH
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

keystone_settings = KeystoneHelper.keystone_settings(node, :cinder)

cinder_port = node[:cinder][:api][:bind_port]
cinder_protocol = node[:cinder][:api][:protocol]

ha_enabled = node[:cinder][:ha][:enabled]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:cinder][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-cinder_register"

keystone_register "cinder api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  action :wakeup
end

keystone_register "register cinder user" do
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

keystone_register "give cinder user access" do
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

keystone_register "register cinder service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  service_name "cinder"
  service_type "volume"
  service_description "Openstack Cinder Service"
  action :add_service
end

keystone_register "register cinder endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  endpoint_service "cinder"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{cinder_protocol}://"\
                     "#{my_public_host}:#{cinder_port}/v1/$(project_id)s"
  endpoint_adminURL "#{cinder_protocol}://"\
                    "#{my_admin_host}:#{cinder_port}/v1/$(project_id)s"
  endpoint_internalURL "#{cinder_protocol}://"\
                       "#{my_admin_host}:#{cinder_port}/v1/$(project_id)s"
  action :add_endpoint
end

keystone_register "register cinder service v2" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  service_name "cinderv2"
  service_type "volumev2"
  service_description "Openstack Cinder Service V2"
  action :add_service
end

keystone_register "register cinder endpoint v2" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  endpoint_service "cinderv2"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{cinder_protocol}://"\
                     "#{my_public_host}:#{cinder_port}/v2/$(project_id)s"
  endpoint_adminURL "#{cinder_protocol}://"\
                    "#{my_admin_host}:#{cinder_port}/v2/$(project_id)s"
  endpoint_internalURL "#{cinder_protocol}://"\
                       "#{my_admin_host}:#{cinder_port}/v2/$(project_id)s"
  action :add_endpoint
end

keystone_register "register cinder service v3" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  service_name "cinderv3"
  service_type "volumev3"
  service_description "Openstack Cinder Service V3"
  action :add_service
end

keystone_register "register cinder endpoint v3" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth lazy { node[:keystone][:admin][:credentials] }
  endpoint_service "cinderv3"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{cinder_protocol}://"\
                     "#{my_public_host}:#{cinder_port}/v3/$(project_id)s"
  endpoint_adminURL "#{cinder_protocol}://"\
                    "#{my_admin_host}:#{cinder_port}/v3/$(project_id)s"
  endpoint_internalURL "#{cinder_protocol}://"\
                       "#{my_admin_host}:#{cinder_port}/v3/$(project_id)s"
  action :add_endpoint
end

crowbar_pacemaker_sync_mark "create-cinder_register"

use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

cinder_service "api" do
  use_pacemaker_provider use_crowbar_pacemaker_service
end
