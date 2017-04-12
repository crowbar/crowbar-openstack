# Copyright 2013, SUSE Inc., Inc.
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

default[:heat][:engine][:service_name] = "heat-engine"
default[:heat][:api][:service_name] = "heat-api"
default[:heat][:api_cfn][:service_name] = "heat-api-cfn"
default[:heat][:api_cloudwatch][:service_name] = "heat-api-cloudwatch"

case node[:platform_family]
when "debian"
  default[:heat][:platform] = {
    packages: [
      "heat-engine",
      "heat-api",
      "heat-api-cfn",
      "heat-api-cloudwatch",
      "python-heat",
      "heat-common",
      "python-heatclient"
    ],
    plugin_packages: [],
    services: [
      "heat-engine",
      "heat-api",
      "heat-api-cfn",
      "heat-api-cloudwatch"
    ]
  }
when "rhel", "suse"
  default[:heat][:platform] = {
    packages: [
      "openstack-heat-engine",
      "openstack-heat-api",
      "openstack-heat-api-cfn",
      "openstack-heat-api-cloudwatch",
      "python-heatclient"
    ],
    plugin_packages: [],
    services: [
      "openstack-heat-engine",
      "openstack-heat-api",
      "openstack-heat-api-cfn",
      "openstack-heat-api-cloudwatch"
    ]
  }
  default[:heat][:engine][:service_name] = "openstack-heat-engine"
  default[:heat][:api][:service_name] = "openstack-heat-api"
  default[:heat][:api_cfn][:service_name] = "openstack-heat-api-cfn"
  default[:heat][:api_cloudwatch][:service_name] = "openstack-heat-api-cloudwatch"
end

if node[:platform_family] == "suse"
  default[:heat][:platform][:plugin_packages] = ["openstack-heat-plugin-heat_docker"]
  default[:heat][:platform][:gbp_plugin_packages] = ["openstack-heat-gbp"]
end

default[:heat][:debug] = false
default[:heat][:verbose] = false
default[:heat][:max_header_line] = 16384

default[:heat][:user] = "heat"
default[:heat][:group] = "heat"

default[:heat]["auth_encryption_key"] = "" # Set by Recipe

default[:heat][:db][:database] = "heat"
default[:heat][:db][:user] = "heat"
default[:heat][:db][:password] = "" # Set by Recipe

default[:heat][:service_user] = "heat"
default[:heat][:service_password] = ""

default[:heat][:api][:protocol] = "http"
default[:heat][:api][:cfn_port] = 8000
default[:heat][:api][:engine_port] = 8001
default[:heat][:api][:cloud_watch_port] = 8003
default[:heat][:api][:port] = 8004

default[:heat][:metering_secret] = "" # Set by Recipe

default[:heat][:ha][:enabled] = false
# Ports to bind to when haproxy is used for the real ports
default[:heat][:ha][:ports][:cfn_port] = 5570
default[:heat][:ha][:ports][:api_port] = 5571
default[:heat][:ha][:ports][:cloud_watch_port] = 5572

# Pacemaker bits
default[:heat][:ha][:engine][:agent] = "lsb:#{default[:heat][:engine][:service_name]}"
default[:heat][:ha][:engine][:op][:monitor][:interval] = "10s"
default[:heat][:ha][:api][:agent] = "lsb:#{default[:heat][:api][:service_name]}"
default[:heat][:ha][:api][:op][:monitor][:interval] = "10s"
default[:heat][:ha][:api_cfn][:agent] = "lsb:#{default[:heat][:api_cfn][:service_name]}"
default[:heat][:ha][:api_cfn][:op][:monitor][:interval] = "10s"
default[:heat][:ha][:api_cloudwatch][:agent] = "lsb:#{default[:heat][:api_cloudwatch][:service_name]}"
default[:heat][:ha][:api_cloudwatch][:op][:monitor][:interval] = "10s"
