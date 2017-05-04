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

network_settings = MagnumHelper.network_settings(node)
bind_port = network_settings[:api][:bind_port]
bind_host = network_settings[:api][:bind_host]
api_protocol = node[:magnum][:api][:protocol]

monitor_url = "#{api_protocol}://#{bind_host}:#{bind_port}/"

# monasca-agent "http_check" plugin
monasca_agent_plugin_http_check "http_check for container-infra-api" do
  built_by "magnum-server"
  name "container-infra-api"
  url monitor_url
  dimensions "service" => "container-infra-api"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for magnum DB" do
  built_by "magnum-server"
  host db_settings[:address]
  username node[:magnum][:db][:user]
  password node[:magnum][:db][:password]
  dbname node[:magnum][:db][:database]
end
