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

network_settings = SaharaHelper.network_settings(node)

monitor_url = "#{node[:sahara][:api][:protocol]}://#{network_settings[:api][:bind_host]}:" \
              "#{network_settings[:api][:bind_port]}/"

monasca_agent_plugin_http_check "http_check for sahara-api" do
  built_by "sahara-server"
  name "data-processing-api"
  url monitor_url
  dimensions "service" => "data-processing-api"
end

# monasca-agent "postgres" plugin
db_settings = fetch_database_settings

monasca_agent_plugin_postgres "postgres check for sahara DB" do
  built_by "sahara-server"
  host db_settings[:address]
  username node[:sahara][:db][:user]
  password node[:sahara][:db][:password]
  dbname node[:sahara][:db][:database]
end
