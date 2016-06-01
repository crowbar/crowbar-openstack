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

package "openstack-barbican-api"

apache_module "deflate" do
  conf false
  enable true
end

apache_site "000-default" do
  enable false
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

bind_port = node[:barbican][:api][:bind_port]
admin_host = CrowbarHelper.get_host_for_admin_url(node, false)
public_host = CrowbarHelper.get_host_for_public_url(node, false, false)
register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

node.normal[:apache][:listen_ports_crowbar] ||= {}

node.normal[:apache][:listen_ports_crowbar][:barbican] = { plain: bind_port }

# Override what the apache2 cookbook does since it enforces the ports
resource = resources(template: "#{node[:apache][:dir]}/ports.conf")
resource.variables(
  apache_listen_ports:
    node.normal[:apache][:listen_ports_crowbar].values.map(&:values).flatten.uniq.sort
)

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
  endpoint_publicURL "http://#{public_host}:#{bind_port}"
  endpoint_adminURL "http://#{admin_host}:#{bind_port}"
  endpoint_internalURL "http://#{admin_host}:#{bind_port}"
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

keystone_register "give barbican user access" do
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

template "#{node[:apache][:dir]}/vhosts.d/barbican-api.conf" do
  path "#{node[:apache][:dir]}/vhosts.d/barbican-api.conf"
  source "barbican-api.conf.erb"
  mode 0644
  variables(
    application_path: application_path,
    application_exec_path: application_exec_path,
    barbican_user: node[:barbican][:user],
    barbican_group: node[:barbican][:group],
    bind_host: node[:barbican][:api][:bind_host],
    bind_port: node[:barbican][:api][:bind_port],
    logfile: node[:barbican][:api][:logfile],
    processes: node[:barbican][:api][:processes],
    threads: node[:barbican][:api][:threads],
  )
  notifies :reload, resources(service: "apache2")
end

apache_site "barbican-api.conf" do
  enable true
end
