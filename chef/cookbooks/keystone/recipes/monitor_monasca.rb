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

if node[:keystone][:ha][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_admin_host = admin_address
  bind_admin_port = node[:keystone][:ha][:ports][:admin_port]
else
  bind_admin_host = node[:keystone][:api][:admin_host]
  bind_admin_port = node[:keystone][:api][:admin_port]
end

# we want to monitor the service that is locally available (*not* the port bind to haproxy)
monitor_url = "#{node[:keystone][:api][:protocol]}://#{bind_admin_host}:#{bind_admin_port}/"

monasca_agent_plugin_http_check "http_check for keystone" do
  built_by "keystone-server"
  name "identity-api"
  url monitor_url
  dimensions "service" => "identity-api"
  match_pattern ".*v#{keystone_settings["api_version"]}.*"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for keystone DB" do
  built_by "keystone-server"
  host db_settings[:address]
  username node[:keystone][:db][:user]
  password node[:keystone][:db][:password]
  dbname node[:keystone][:db][:database]
end
