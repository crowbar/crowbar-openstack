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

aodh_api_service_name = "aodh-api"
aodh_evaluator_service_name = "aodh-evaluator"
aodh_notifier_service_name = "aodh-notifier"
aodh_listener_service_name = "aodh-listener"

if %w(rhel suse).include?(node[:platform_family])
  polling_service_name = "openstack-ceilometer-polling"
  api_service_name = "openstack-ceilometer-api"
  collector_service_name = "openstack-ceilometer-collector"
  agent_notification_service_name = "openstack-ceilometer-agent-notification"
  aodh_api_service_name = "openstack-aodh-api"
  aodh_evaluator_service_name = "openstack-aodh-evaluator"
  aodh_notifier_service_name = "openstack-aodh-notifier"
  aodh_listener_service_name = "openstack-aodh-listener"
end

default[:ceilometer][:api][:service_name] = api_service_name
default[:ceilometer][:collector][:service_name] = collector_service_name
default[:ceilometer][:agent_notification][:service_name] = agent_notification_service_name
default[:ceilometer][:polling][:service_name] = polling_service_name

default[:ceilometer][:aodh][:api][:service_name] = aodh_api_service_name
default[:ceilometer][:aodh][:evaluator][:service_name] = aodh_evaluator_service_name
default[:ceilometer][:aodh][:notifier][:service_name]  = aodh_notifier_service_name
default[:ceilometer][:aodh][:listener][:service_name]  = aodh_listener_service_name
# FIXME: expirer not mentioned in install guides... ?
# default[:ceilometer][:aodh][:expirer][:service_name]  = aodh_expirer_service_name

default[:ceilometer][:aodh][:user] = "aodh"
default[:ceilometer][:aodh][:group] = "aodh"

default[:ceilometer][:aodh][:service_user] = "aodh"
default[:ceilometer][:aodh][:service_password] = ""

default[:ceilometer][:aodh][:api][:protocol] = "http"
default[:ceilometer][:aodh][:api][:host] = "0.0.0.0"
default[:ceilometer][:aodh][:api][:port] = 8042

# Ports to bind to when haproxy is used for the real ports
default[:ceilometer][:aodh][:ha][:ports][:api] = 5562
# FIXME: could we use 5562?

default[:ceilometer][:aodh][:db][:database] = "aodh"
default[:ceilometer][:aodh][:db][:user] = "aodh"
default[:ceilometer][:aodh][:db][:password] = ""

default[:ceilometer][:debug] = false
default[:ceilometer][:verbose] = false

default[:ceilometer][:use_mongodb] = false

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

default[:ceilometer][:aodh][:ha][:api][:agent] = "lsb:#{aodh_api_service_name}"
default[:ceilometer][:aodh][:ha][:api][:op][:monitor][:interval] = "10s"
default[:ceilometer][:aodh][:ha][:evaluator][:agent] = "lsb:#{aodh_evaluator_service_name}"
default[:ceilometer][:aodh][:ha][:evaluator][:op][:monitor][:interval] = "10s"
default[:ceilometer][:aodh][:ha][:notifier][:agent] = "lsb:#{aodh_notifier_service_name}"
default[:ceilometer][:aodh][:ha][:notifier][:op][:monitor][:interval] = "10s"
default[:ceilometer][:aodh][:ha][:listener][:agent] = "lsb:#{aodh_listener_service_name}"
default[:ceilometer][:aodh][:ha][:listener][:op][:monitor][:interval] = "10s"

default[:ceilometer][:ha][:polling][:enabled] = false
default[:ceilometer][:ha][:polling][:agent] = "lsb:#{polling_service_name}"
default[:ceilometer][:ha][:polling][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:ceilometer][:ha][:ports][:api] = 5561
if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
  default[:ceilometer][:ha][:mongodb][:agent] = "lsb:mongodb"
else
  default[:ceilometer][:ha][:mongodb][:agent] = "systemd:mongodb"
end
default[:ceilometer][:ha][:mongodb][:op][:monitor][:interval] = "10s"
default[:ceilometer][:ha][:mongodb][:replica_set][:name] = "crowbar-ceilometer"
default[:ceilometer][:ha][:mongodb][:replica_set][:member] = false
# this establishes which node is used for mongo client connections that
# we use to initialize the replica set
default[:ceilometer][:ha][:mongodb][:replica_set][:controller] = false
