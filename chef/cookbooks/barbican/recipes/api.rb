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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"
include_recipe "#{@cookbook_name}::common"

application_path = "/srv/www/barbican-api"
application_exec_path = "#{application_path}/app.wsgi"

ha_enabled = node[:barbican][:ha][:enabled]

package "openstack-barbican-api"

apache_module "deflate" do
  conf false
  enable true
end

apache_site "000-default" do
  enable false
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
network_settings = BarbicanHelper.network_settings(node)

if node[:barbican][:api][:protocol] == "https"
  ssl_setup "setting up ssl for barbican" do
    generate_certs node[:barbican][:ssl][:generate_certs]
    certfile node[:barbican][:ssl][:certfile]
    keyfile node[:barbican][:ssl][:keyfile]
    group node[:barbican][:group]
    fqdn node[:fqdn]
    cert_required node[:barbican][:ssl][:cert_required]
    ca_certs node[:barbican][:ssl][:ca_certs]
  end
end

bind_port = network_settings[:api][:bind_port]
barbican_port = node[:barbican][:api][:bind_port]
barbican_protocol = node[:barbican][:api][:protocol]
admin_host = CrowbarHelper.get_host_for_admin_url(node, node[:barbican][:ha][:enabled])
public_host = CrowbarHelper.get_host_for_public_url(node,
                                                    barbican_protocol == "https",
                                                    node[:barbican][:ha][:enabled])
register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

crowbar_pacemaker_sync_mark "wait-barbican_register" if ha_enabled

keystone_register "barbican api wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

# Create barbican service
keystone_register "register barbican service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "barbican"
  service_type "key-manager"
  service_description "Openstack Barbican - Key and Secret Management Service"
  action :add_service
end

keystone_register "register barbican endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "barbican"
  service_type "key-manager"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{barbican_protocol}://#{public_host}:#{barbican_port}"
  endpoint_adminURL "#{barbican_protocol}://#{admin_host}:#{barbican_port}"
  endpoint_internalURL "#{barbican_protocol}://#{admin_host}:#{barbican_port}"
  action :add_endpoint_template
end

keystone_register "register barbican user" do
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

keystone_register "give barbican user access as admin" do
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

keystone_register "add key-manager:service-admin role for barbican" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  role_name "key-manager:service-admin"
  action :add_role
end

keystone_register "give barbican user access as key-manager:service-admin" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "key-manager:service-admin"
  action :add_access
end

keystone_register "add creator role for barbican" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  role_name "creator"
  action :add_role
end

keystone_register "give barbican user access as creator" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "creator"
  action :add_access
end

keystone_register "add observer role for barbican" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  role_name "observer"
  action :add_role
end

keystone_register "give barbican user access as observer" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "observer"
  action :add_access
end

keystone_register "add audit role for barbican" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  role_name "audit"
  action :add_role
end

keystone_register "give barbican user access as audit" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "audit"
  action :add_access
end

crowbar_pacemaker_sync_mark "create-barbican_register" if ha_enabled

if node[:barbican][:ha][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:barbican][:ha][:ports][:api]
else
  bind_host = node[:barbican][:api][:bind_host]
  bind_port = node[:barbican][:api][:bind_port]
end

crowbar_openstack_wsgi "WSGI entry for barbican-api" do
  bind_host bind_host
  bind_port bind_port
  daemon_process "barbican-api"
  user node[:barbican][:user]
  group node[:barbican][:group]
  processes node[:barbican][:api][:processes]
  threads node[:barbican][:api][:threads]
  ssl_enable node[:barbican][:api][:protocol] == "https"
  ssl_certfile node[:barbican][:ssl][:certfile]
  ssl_keyfile node[:barbican][:ssl][:keyfile]
  if node[:barbican][:ssl][:cert_required]
    ssl_cacert node[:barbican][:ssl][:ca_certs]
  end
end

apache_site "barbican-api.conf" do
  enable true
end
