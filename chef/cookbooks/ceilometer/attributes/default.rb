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

central_service_name = "ceilometer-agent-central"
if %w(suse).include?(node[:platform])
  central_service_name = "openstack-ceilometer-agent-central"
elsif %w(redhat centos).include?(node[:platform])
  central_service_name = "openstack-ceilometer-central"
end

api_service_name = "ceilometer-api"
if %w(redhat centos suse).include?(node[:platform])
  api_service_name = "openstack-ceilometer-api"
end

collector_service_name = "ceilometer-collector"
if %w(redhat centos suse).include?(node[:platform])
  collector_service_name = "openstack-ceilometer-collector"
end

default[:ceilometer][:api][:service_name] = api_service_name
default[:ceilometer][:collector][:service_name] = collector_service_name
default[:ceilometer][:central][:service_name] = central_service_name

default[:ceilometer][:debug] = false
default[:ceilometer][:verbose] = false

default[:ceilometer][:use_mongodb] = true

default[:ceilometer][:meters_interval] = 600
default[:ceilometer][:cpu_interval] = 600

default[:ceilometer][:db][:database] = "ceilometer"
default[:ceilometer][:db][:user] = "ceilometer"
default[:ceilometer][:db][:password] = "" # Set by wrapper

default[:ceilometer][:keystone_service_user] = "ceilometer"
default[:ceilometer][:keystone_service_password] = ""

default[:ceilometer][:api][:protocol] = "http"
default[:ceilometer][:api][:port] = 8777

default[:ceilometer][:metering_secret] = "" # Set by wrapper

default[:ceilometer][:ha][:server][:enabled] = false

default[:ceilometer][:ha][:api][:agent] = "lsb:#{api_service_name}"
default[:ceilometer][:ha][:api][:op][:monitor][:interval] = "10s"
default[:ceilometer][:ha][:collector][:agent] = "lsb:#{collector_service_name}"
default[:ceilometer][:ha][:collector][:op][:monitor][:interval] = "10s"

default[:ceilometer][:ha][:central][:enabled] = false
default[:ceilometer][:ha][:central][:agent] = "lsb:#{central_service_name}"
default[:ceilometer][:ha][:central][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:ceilometer][:ha][:ports][:api] = 5560
