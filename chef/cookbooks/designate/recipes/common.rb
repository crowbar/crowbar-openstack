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

package "openstack-designate"

designate_server_node = node_search_with_cache("roles:designate-server").first
network_settings = DesignateHelper.network_settings(designate_server_node)
db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

public_host = CrowbarHelper.get_host_for_public_url(designate_server_node,
                                                    node[:designate][:api][:protocol] == "https",
                                                    node[:designate][:ha][:enabled])

# get Database data
sql_connection = fetch_database_connection_string(node[:designate][:db])

memcached_instance("designate") if node["roles"].include?("designate-server")

api_protocol = node[:designate][:api][:protocol]

resource_project_id = ""
keystone_settings = KeystoneHelper.keystone_settings(node, :designate)
admin_password = keystone_settings["admin_password"]
old_admin_password = node[:keystone][:admin][:old_password]
if old_admin_password && !old_admin_password.empty? && old_admin_password != admin_password
  # We are in the middle of a password update for the admin user.
  admin_password = old_admin_password
end
env = {
  "OS_USERNAME" => keystone_settings["admin_user"],
  "OS_PASSWORD" => admin_password,
  "OS_PROJECT_NAME" => keystone_settings["admin_tenant"],
  "OS_AUTH_URL" => keystone_settings["internal_auth_url"],
  "OS_IDENTITY_API_VERSION" => "3"
}

if node["roles"].include?("designate-server")
  insecure = keystone_settings["insecure"] ? "--insecure" : ""
  project = node[:designate][:resource_project]
  cmdline = "openstack #{insecure} project show -f value -c id '#{project}'"
  cmd = Mixlib::ShellOut.new(cmdline, environment: env)
  resource_project_id = cmd.run_command.stdout.chomp
  cmd.error!
end

template node[:designate][:config_file] do
  source "designate.conf.erb"
  owner "root"
  group node[:designate][:group]
  mode "0640"
  variables(
    bind_host: network_settings[:api][:bind_host],
    bind_port: network_settings[:api][:bind_port],
    with_authtoken: node["roles"].include?("designate-server"),
    api_base_uri: "#{api_protocol}://#{public_host}:#{node[:designate][:api][:bind_port]}",
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: keystone_settings,
    memcached_servers: MemcachedHelper.get_memcached_servers(node,
      CrowbarPacemakerHelper.cluster_nodes(node, "designate-server")),
    resource_project_id: resource_project_id
  )
end
