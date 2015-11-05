# Copyright 2012, Dell Inc., Inc.
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

default[:ceilometer][:user]="ceilometer"
default[:ceilometer][:group]="ceilometer"

polling_service_name = "ceilometer-polling"
api_service_name = "ceilometer-api"
collector_service_name = "ceilometer-collector"
agent_notification_service_name = "ceilometer-agent-notification"
alarm_evaluator_service_name = "ceilometer-alarm-evaluator"
alarm_notifier_service_name = "ceilometer-alarm-notifier"

if %w(rhel suse).include?(node[:platform_family])
  polling_service_name = "openstack-ceilometer-polling"
  api_service_name = "openstack-ceilometer-api"
  collector_service_name = "openstack-ceilometer-collector"
  agent_notification_service_name = "openstack-ceilometer-agent-notification"
  alarm_evaluator_service_name = "openstack-ceilometer-alarm-evaluator"
  alarm_notifier_service_name = "openstack-ceilometer-alarm-notifier"
end

default[:ceilometer][:api][:service_name] = api_service_name
default[:ceilometer][:collector][:service_name] = collector_service_name
default[:ceilometer][:agent_notification][:service_name] = agent_notification_service_name
default[:ceilometer][:polling][:service_name] = polling_service_name
default["ceilometer"]["alarm_evaluator"]["service_name"] = alarm_evaluator_service_name
default["ceilometer"]["alarm_notifier"]["service_name"] = alarm_notifier_service_name

default[:ceilometer][:debug] = false
default[:ceilometer][:verbose] = false

default[:ceilometer][:use_mongodb] = false
default[:ceilometer][:radosgw_backend] = true

default[:ceilometer][:meters_interval] = 600
default[:ceilometer][:cpu_interval] = 600
default[:ceilometer][:disk_interval] = 600
default[:ceilometer][:network_interval] = 600

default[:ceilometer][:db][:database] = "ceilometer"
default[:ceilometer][:db][:user] = "ceilometer"
default[:ceilometer][:db][:password] = "" # Set by wrapper

default[:ceilometer][:service_user] = "ceilometer"
default[:ceilometer][:service_password] = ""

default[:ceilometer][:api][:protocol] = "http"
default[:ceilometer][:api][:host] = "0.0.0.0"
default[:ceilometer][:api][:port] = 8777

default[:ceilometer][:metering_secret] = "" # Set by wrapper

default[:ceilometer][:database][:metering_time_to_live] = -1
default[:ceilometer][:database][:event_time_to_live] = -1

default[:ceilometer][:mongodb][:port] = 27017

default[:ceilometer][:ha][:server][:enabled] = false

default[:ceilometer][:ha][:api][:agent] = "lsb:#{api_service_name}"
default[:ceilometer][:ha][:api][:op][:monitor][:interval] = "10s"
# increase default timeout: ceilometer has to wait until mongodb is ready
default[:ceilometer][:ha][:api][:op][:start][:timeout] = "60s"
default[:ceilometer][:ha][:collector][:agent] = "lsb:#{collector_service_name}"
default[:ceilometer][:ha][:collector][:op][:monitor][:interval] = "10s"
default[:ceilometer][:ha][:agent_notification][:agent] = "lsb:#{agent_notification_service_name}"
default[:ceilometer][:ha][:agent_notification][:op][:monitor][:interval] = "10s"

default["ceilometer"]["ha"]["alarm_evaluator"]["agent"] = "lsb:#{alarm_evaluator_service_name}"
default["ceilometer"]["ha"]["alarm_evaluator"]["op"]["monitor"]["interval"] = "10s"
default["ceilometer"]["ha"]["alarm_notifier"]["agent"] = "lsb:#{alarm_notifier_service_name}"
default["ceilometer"]["ha"]["alarm_notifier"]["op"]["monitor"]["interval"] = "10s"

default[:ceilometer][:ha][:polling][:enabled] = false
default[:ceilometer][:ha][:polling][:agent] = "lsb:#{polling_service_name}"
default[:ceilometer][:ha][:polling][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:ceilometer][:ha][:ports][:api] = 5561
default[:ceilometer][:ha][:mongodb][:agent] = "lsb:mongodb"
default[:ceilometer][:ha][:mongodb][:op][:monitor][:interval] = "10s"
default[:ceilometer][:ha][:mongodb][:replica_set][:name] = "crowbar-ceilometer"
default[:ceilometer][:ha][:mongodb][:replica_set][:member] = false
# this establishes which node is used for mongo client connections that
# we use to initialize the replica set
default[:ceilometer][:ha][:mongodb][:replica_set][:controller] = false
