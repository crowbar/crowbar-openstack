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

default[:ceilometer][:db][:database] = "ceilometer"
default[:ceilometer][:db][:user] = "ceilometer"
default[:ceilometer][:db][:password] = "" # Set by Recipe

default[:ceilometer][:keystone_service_user] = "ceilometer"
default[:ceilometer][:keystone_service_password] = ""

default[:ceilometer][:api][:protocol] = "http"
default[:ceilometer][:api][:port] = 8777

default[:ceilometer][:metering_secret] = "" # Set by Recipe
