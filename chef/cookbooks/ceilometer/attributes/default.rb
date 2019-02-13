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
default[:ceilometer][:config_file] = "/etc/ceilometer/ceilometer.conf.d/100-ceilometer.conf"

central_service_name = "ceilometer-agent-central"
api_service_name = "ceilometer-api"
agent_notification_service_name = "ceilometer-agent-notification"

if %w(rhel suse).include?(node[:platform_family])
  central_service_name = "openstack-ceilometer-agent-central"
  api_service_name = "openstack-ceilometer-api"
  agent_notification_service_name = "openstack-ceilometer-agent-notification"
end

default[:ceilometer][:api][:service_name] = api_service_name
default[:ceilometer][:agent_notification][:service_name] = agent_notification_service_name
default[:ceilometer][:central][:service_name] = central_service_name

default[:ceilometer][:debug] = false

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

default[:ceilometer][:ssl][:certfile] = "/etc/ceilometer/ssl/certs/signing_cert.pem"
default[:ceilometer][:ssl][:keyfile] = "/etc/ceilometer/ssl/private/signing_key.pem"
default[:ceilometer][:ssl][:generate_certs] = false
default[:ceilometer][:ssl][:insecure] = false
default[:ceilometer][:ssl][:cert_required] = false
default[:ceilometer][:ssl][:ca_certs] = "/etc/ceilometer/ssl/certs/ca.pem"

default[:ceilometer][:ha][:server][:enabled] = false

default[:ceilometer][:ha][:api][:op][:start][:timeout] = "60s"
default[:ceilometer][:ha][:agent_notification][:agent] = "systemd:#{agent_notification_service_name}"
default[:ceilometer][:ha][:agent_notification][:op][:monitor][:interval] = "10s"

default[:ceilometer][:ha][:central][:enabled] = false
default[:ceilometer][:ha][:central][:agent] = "systemd:#{central_service_name}"
default[:ceilometer][:ha][:central][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:ceilometer][:ha][:ports][:api] = 5561

default[:ceilometer][:monasca][:field_definitions] = "/etc/ceilometer/monasca_field_definitions.yaml"
