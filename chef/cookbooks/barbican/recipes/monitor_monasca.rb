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

network_settings = BarbicanHelper.network_settings(node)
bind_host = network_settings[:api][:ha_bind_host]
bind_port = network_settings[:api][:bind_port]

monitor_url = "#{node[:barbican][:api][:protocol]}://#{bind_host}:#{bind_port}/"

monasca_agent_plugin_http_check "http_check for barbican-api" do
  built_by "barbica-controller"
  name "key-manager-api"
  url monitor_url
  dimensions "service" => "key-manager-api"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for barbican DB" do
  built_by "barbican-controller"
  host db_settings[:address]
  username node[:barbican][:db][:user]
  password node[:barbican][:db][:password]
  dbname node[:barbican][:db][:database]
end
