#
# Copyright 2016 SUSE
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

node[:neutron][:platform][:midonet_pkgs].each { |p| package p }

if node.roles.include?("neutron-server")
  keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

  crowbar_pacemaker_sync_mark "wait-midonet_register"

  keystone_register "register midonet service" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    token keystone_settings["admin_token"]
    service_name "midonet"
    service_type "midonet"
    service_description "MidoNet API Service"
    action :add_service
  end

  keystone_register "add #{node[:neutron][:midonet][:openstack_user]} user" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    token keystone_settings["admin_token"]
    user_name node[:neutron][:midonet][:openstack_user]
    user_password node[:neutron][:midonet][:openstack_password]
    tenant_name keystone_settings["service_tenant"]
    action :add_user
  end

  keystone_register "add admin role for #{node[:neutron][:midonet][:openstack_user]}" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    token keystone_settings["admin_token"]
    user_name node[:neutron][:midonet][:openstack_user]
    role_name "admin"
    tenant_name keystone_settings["service_tenant"]
    action :add_access
  end

  crowbar_pacemaker_sync_mark "create-midonet_register"
end
