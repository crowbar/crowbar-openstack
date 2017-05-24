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

monitor_url = MonascaHelper.api_admin_url(node)
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(node)

monasca_agent_plugin_http_check "http_check for monasca-api" do
  built_by "monasca-server"
  name "monitoring-api"
  url monitor_url
  dimensions "service" => "monitoring-api"
end

# influxdb
influxdb_monitor_url = "http://#{monasca_net_ip}:8086/ping"
monasca_agent_plugin_http_check "http_check for influxdb" do
  built_by "influxdb"
  name "influxdb"
  url influxdb_monitor_url
  dimensions "service" => "influxdb"
end

# kafka
# FIXME: keep disabled until https://storyboard.openstack.org/#!/story/2001036
# is done
# consumer_groups = { "thresh-event" => { "events" => [] },
#                     "thresh-metric" => { "metrics" => [] } }
# monasca_agent_plugin_kafka "kafka monitoring" do
#   built_by "monasca-server"
#   name "kafka"
#   kafka_connect_str monasca_net_ip
#   consumer_groups consumer_groups
# end

# zookeeper
monasca_agent_plugin_zookeeper "zookeeper monitoring" do
  built_by "monasca-server"
  name "zookeeper"
  host monasca_net_ip
end
