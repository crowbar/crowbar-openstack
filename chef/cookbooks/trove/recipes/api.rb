#
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
# Cookbook Name:: trove
# Recipe:: api
#

keystone_settings = KeystoneHelper.keystone_settings(node, :trove)
ha_enabled = false
trove_protocol = node[:trove][:api][:protocol]
trove_port = node[:trove][:api][:bind_port]

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:trove][:api][:protocol] == "https", ha_enabled
)


# address/port binding
my_ipaddress = Barclamp::Inventory.get_network_by_type(node, "admin").address
node.set[:trove][:my_ip] = my_ipaddress
node.set[:trove][:api][:bind_host] = my_ipaddress

bind_host = node[:trove][:api][:bind_host]
if ha_enabled
  bind_port = node[:trove][:ha][:ports][:api]
else
  if node[:trove][:api][:bind_open_address]
    bind_host = "0.0.0.0"
  end
  bind_port = node[:trove][:api][:bind_port]
end

sql_connection = TroveHelper.get_sql_connection node

rabbitmq_servers = node_search_with_cache("roles:rabbitmq-server")
rabbitmq_trove_settings = TroveHelper.get_rabbitmq_trove_url(node, rabbitmq_servers)

nova_controllers = node_search_with_cache("roles:nova-controller")
nova_url, nova_insecure = TroveHelper.get_nova_details nova_controllers, keystone_settings

cinder_controllers = node_search_with_cache("roles:cinder-controller")
cinder_url, cinder_insecure = TroveHelper.get_cinder_details cinder_controllers

swift_proxies = node_search_with_cache("roles:swift-proxy")
ceph_radosgws = search_env_filtered(:node, "roles:ceph-radosgw")

object_store_url, object_store_insecure =
  TroveHelper.get_objectstore_details swift_proxies, ceph_radosgws


crowbar_pacemaker_sync_mark "wait-trove_register" if ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "trove api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register trove user" do
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

keystone_register "give trove user access" do
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

keystone_register "register trove service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "trove"
  service_type "database"
  service_description "Openstack Trove database service"
  action :add_service
end

keystone_register "register trove endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "trove"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{trove_protocol}://"\
                     "#{my_public_host}:#{trove_port}/v1.0/$(project_id)s"
  endpoint_adminURL "#{trove_protocol}://"\
                    "#{my_admin_host}:#{trove_port}/v1.0/$(project_id)s"
  endpoint_internalURL "#{trove_protocol}://"\
                       "#{my_admin_host}:#{trove_port}/v1.0/$(project_id)s"
  #  endpoint_global true
  #  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-trove_register" if ha_enabled


template node[:trove][:api][:config_file] do
  source "trove.conf.erb"
  owner "root"
  group node[:trove][:group]
  mode "0640"
  variables(
    keystone_settings: keystone_settings,
    sql_connection: sql_connection,
    rabbit_default_settings: fetch_rabbitmq_settings,
    rabbit_trove_settings: rabbitmq_trove_settings,
    nova_url: nova_url,
    nova_insecure: nova_insecure,
    cinder_url: cinder_url,
    cinder_insecure: cinder_insecure,
    object_store_url: object_store_url,
    object_store_insecure: object_store_insecure,
    bind_host: bind_host,
    bind_port: bind_port
  )
  notifies :restart, "service[trove-api]"
end

trove_service("api")
