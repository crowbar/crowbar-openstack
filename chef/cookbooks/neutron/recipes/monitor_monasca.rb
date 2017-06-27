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

bind_port = node[:neutron][:api][:service_port]

if node[:neutron][:ha][:server][:enabled]
  bind_host = CrowbarPacemakerHelper.cluster_vip(node, "admin")
else
  bind_host = NeutronHelper.get_bind_host_port(node)[0]
end

monitor_url = "#{node[:neutron][:api][:protocol]}://#{bind_host}:#{bind_port}/"

monasca_agent_plugin_http_check "http_check for neutron-api" do
  built_by "neutron-server"
  name "network-api"
  url monitor_url
  dimensions "service" => "network-api"
  match_pattern ".*v2.0*"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for neutron DB" do
  built_by "neutron-server"
  host db_settings[:address]
  username node[:neutron][:db][:user]
  password node[:neutron][:db][:password]
  dbname node[:neutron][:db][:database]
end
