#
# Cookbook Name:: nsx
# Attributes:: default
#
# Copyright 2013, cloudbau GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default[:nsx][:controllers] = []
#
# to be used like this:
#
#  "nsx" => {
#    "controllers" => [
#      {
#        :host => '10.127.1.10',
#        :port => 443,
#        :username => 'admin',
#        :password => 'admin'
#      }
#    ]
#  }
default[:nsx][:nsx_cluster_uuid] = nil
default[:nsx][:default_tz_uuid] = nil
default[:nsx][:default_l3_gateway_service_uuid] = nil
default[:nsx][:default_l3_gateway_service_uuid] = nil
default[:nsx][:default_iface_name] = nil
