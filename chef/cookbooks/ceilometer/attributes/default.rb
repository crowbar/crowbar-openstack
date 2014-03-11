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

unless node[:platform] == "suse"
  default[:ceilometer][:user]="ceilometer"
  default[:ceilometer][:group]="ceilometer"
else
  default[:ceilometer][:user]="openstack-ceilometer"
  default[:ceilometer][:group]="openstack-ceilometer"
end

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
default[:ceilometer][:ha][:central][:enabled] = false
# Ports to bind to when haproxy is used for the real ports
default[:ceilometer][:ha][:ports][:api] = 5560

lsb_service_name = "ceilometer-agent-central"
if %w(suse).include?(node[:platform])
  lsb_service_name = "openstack-ceilometer-agent-central"
elsif %w(redhat centos).include?(node[:platform])
  lsb_service_name = "openstack-ceilometer-central"
end

default[:ceilometer][:agent_central][:service_name]     = lsb_service_name

default[:ceilometer][:ha][:central][:agent] = "lsb:#{lsb_service_name}"
# use OCF agent once it is able to use LSB services internally
#default[:ceilometer][:ha][:central][:agent] = "ocf:openstack:ceilometer-agent-central"
default[:ceilometer][:ha][:central][:op][:monitor][:interval] = "10s"
