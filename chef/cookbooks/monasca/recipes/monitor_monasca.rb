#
# Copyright 2018 SUSE Linux GmbH
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
return if no_monasca_server_or_master

monasca_server = node_search_with_cache("roles:monasca-server").first
monasca_log_api_url = MonascaHelper.log_api_healthcheck_url(monasca_server)
kibana_url = "http://" + MonascaHelper.monasca_public_host(monasca_server) + ":5601"

# http checks
monasca_agent_plugin_http_check "http_check for monasca-log-api" do
  built_by "monasca-log-api"
  name "monasca-log-api"
  url monasca_log_api_url
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-api" })
  timeout 10
  use_keystone true
end

monasca_agent_plugin_http_check "http_check for kibana" do
  built_by "kibana"
  name "kibana"
  url kibana_url
  dimensions ({ "service" => "monitoring", "component" => "kibana" })
  timeout 10
  use_keystone false
end

# process checks
monasca_agent_plugin_process "process for monasca-log-api" do
  built_by "monasca-log-api"
  name "monasca-log-api"
  search_string ["monasca-log-api"]
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-api" })
end

monasca_agent_plugin_process "process for monasca-log-metrics" do
  built_by "monasca-log-metrics"
  name "monasca-log-metrics"
  search_string ["logstash/runner.rb agent -f /etc/monasca-log-metrics/monasca-log-metrics.conf"]
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-metrics" })
end

monasca_agent_plugin_process "process for monasca-log-persister" do
  built_by "monasca-log-persister"
  name "monasca-log-persister"
    search_string ["logstash/runner.rb agent -f /etc/monasca-log-persister/monasca-log-persister.conf"]
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-persister" })
end

monasca_agent_plugin_process "process for monasca-log-transformer" do
  built_by "monasca-log-transformer"
  name "monasca-log-transformer"
    search_string ["logstash/runner.rb agent -f /etc/monasca-log-transformer/monasca-log-transformer.conf"]
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-transformer" })
end
