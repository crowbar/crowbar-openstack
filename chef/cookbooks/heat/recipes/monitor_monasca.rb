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

bind_host, api_port, _cfn_port = HeatHelper.get_bind_host_port(node)

monitor_url = "#{node[:heat][:api][:protocol]}://#{bind_host}:#{api_port}/"

monasca_agent_plugin_http_check "http_check for heat-api" do
  built_by "heat-server"
  name "orchestration-api"
  url monitor_url
  dimensions "service" => "orchestration-api"
  match_pattern ".*v1.0*"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for heat DB" do
  built_by "heat-server"
  host db_settings[:address]
  username node[:heat][:db][:user]
  password node[:heat][:db][:password]
  dbname node[:heat][:db][:database]
end
