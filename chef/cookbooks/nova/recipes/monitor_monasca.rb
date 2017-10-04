#
# Copyright 2017 SUSE Linux GmbH
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

return unless node["roles"].include?("monasca-agent")

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

is_compute = false

if node[:monasca][:agent][:monitor_libvirt]
  node["roles"].each do |role|
    re_match = role.match "^nova-compute"
    is_compute = true unless re_match.nil?

    unless is_compute && (["kvm", "lxc", "qemu", "xen"].include? node[:nova][:libvirt_type])
      next
    end

    monasca_agent_plugin_libvirt "libvirt check for nova-compute" do
      user_domain_name "Default"
      project_domain_name "Default"
      region_name keystone_settings["endpoint_region"]
      username keystone_settings["service_user"]
      password keystone_settings["service_password"]
      project_name keystone_settings["service_tenant"]
      auth_url keystone_settings["internal_auth_url"]
    end
  end
end

# No need to proceed beyond this point on a compute node
return unless node["roles"].include?("nova-controller")

if node[:nova][:ha][:enabled]
  bind_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_port = node[:nova][:ha][:ports][:api]
else
  bind_host = "0.0.0.0"
  bind_port = node[:nova][:ports][:api]
end
api_protocol = node[:nova][:ssl][:enabled] ? "https" : "http"

monitor_url = "#{api_protocol}://#{bind_host}:#{bind_port}/"

monasca_agent_plugin_http_check "http_check for nova-api" do
  built_by "nova-controller"
  name "compute-api"
  url monitor_url
  dimensions "service" => "compute-api"
  match_pattern ".*v2.1*"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for nova DB" do
  built_by "nova-controller-nova"
  host db_settings[:address]
  username node[:nova][:db][:user]
  password node[:nova][:db][:password]
  dbname node[:nova][:db][:database]
end

monasca_agent_plugin_postgres "postgres check for nova_api DB" do
  built_by "nova-controller-nova_api"
  host db_settings[:address]
  username node[:nova][:api_db][:user]
  password node[:nova][:api_db][:password]
  dbname node[:nova][:api_db][:database]
end
