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

# http_check
monasca_agent_plugin_http_check "http_check for monasca-api" do
  built_by "monasca-api"
  name "monitoring-api"
  url monitor_url
  dimensions ({ "service" => "monitoring", "component" => "monasca-api" })
end

monasca_agent_plugin_http_check "http_check for monasca-log-api" do
  built_by "monasca-log-api"
  name "monasca-log-api"
  url monitor_url
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-api" })
  use_keystone false
end

monasca_agent_plugin_http_check "http_check for monasca-persister" do
  built_by "monasca-persister"
  name "monasca-persister"
  url "http://#{monasca_net_ip}:8191/healthcheck"
  dimensions ({ "service" => "monitoring", "component" => "monasca-persister" })
  use_keystone false
end

# influxdb
influxdb_monitor_url = "http://#{monasca_net_ip}:8086/ping"
monasca_agent_plugin_http_check "http_check for influxdb" do
  built_by "influxdb"
  name "influxdb"
  url influxdb_monitor_url
  dimensions ({ "service" => "monitoring", "component" => "influxdb" })
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

# postfix
monasca_agent_plugin_postfix "postfix monitoring" do
  built_by "monasca-server"
  name "postfix"
  directory "/var/spool/postfix"
  queues [ "incoming", "active", "deferred" ]

end

# process checks
monasca_agent_plugin_process "monasca-api process" do
  built_by "monasca-api"
  name "monasca-api"
  dimensions ({ "service" => "monitoring", "component" => "monasca-api" })
  detailed true
  search_string [ "monasca-api" ]
end

monasca_agent_plugin_process "monasca-log-api process" do
  built_by "monasca-log-api"
  name "monasca-log-api"
  dimensions ({ "service" => "monitoring", "component" => "monasca-log-api" })
  detailed true
  search_string [ "monasca-log-api" ]
end

monasca_agent_plugin_process "monasca-persister process" do
  built_by "monasca-persister"
  name "monasca-persister"
  dimensions ({ "service" => "monitoring", "component" => "monasca-persister" })
  detailed true
  search_string [ "monasca-persister" ]
end

monasca_agent_plugin_process "monasca-notification process" do
  built_by "monasca-notification"
  name "monasca-notification"
  dimensions ({ "service" => "monitoring", "component" => "monasca-notification" })
  detailed true
  search_string [ "monasca-notification" ]
end

monasca_agent_plugin_process "influxd process" do
  built_by "influxd"
  name "influxd"
  dimensions ({ "service" => "monitoring", "component" => "influxd" })
  detailed true
  search_string [ "influxd" ]
end

monasca_agent_plugin_process "apache storm nimbus" do
  built_by "apache-storm-nimbus"
  name "storm.daemon.nimbus"
  dimensions ({ "service" => "monitoring", "component" => "apache-storm" })
  detailed false
  search_string [ "storm.daemon.nimbus" ]
end

monasca_agent_plugin_process "apache storm supervisor" do
  built_by "apache-storm-supervisor"
  name "storm.daemon.supervisor"
  dimensions ({ "service" => "monitoring", "component" => "apache-storm" })
  detailed false
  search_string [ "storm.daemon.supervisor" ]
end

monasca_agent_plugin_process "apache storm worker" do
  built_by "apache-storm-worker"
  name "storm.daemon.worker"
  dimensions ({ "service" => "monitoring", "component" => "apache-storm" })
  detailed false
  search_string [ "storm.daemon.worker" ]
end
