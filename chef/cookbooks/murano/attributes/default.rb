# Copyright 2017, SUSE Linux GmbH
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

default[:murano][:debug] = false
default[:murano][:verbose] = false
override[:murano][:user] = "murano"
override[:murano][:group] = "murano"
default[:murano][:max_header_line] = 16384
default[:murano][:api][:protocol] = "http"
default[:murano][:api][:bind_port] = 8082
default[:murano][:use_syslog] = false
default[:murano][:core_package_location] = "/usr/lib/murano/io.murano.zip"

default[:murano][:ha][:enabled] = false

# Ports to bind to when haproxy is used for the real ports
default[:murano][:ha][:ports][:api_port] = 5574

if ["rhel", "suse"].include? node[:platform_family]
  api = "lsb:openstack-murano-api"
  engine = "lsb:openstack-murano-engine"
else
  api = "lsb:murano-api"
  engine = "lsb:murano-engine"
end

default[:murano][:ha][:api][:ra] = api
default[:murano][:ha][:engine][:ra] = engine

default[:murano][:ha][:op][:monitor][:interval] = "10s"

default[:murano][:ssl][:certfile] = "/etc/murano/ssl/certs/signing_cert.pem"
default[:murano][:ssl][:keyfile] = "/etc/murano/ssl/private/signing_key.pem"
default[:murano][:ssl][:generate_certs] = false
default[:murano][:ssl][:insecure] = false
default[:murano][:ssl][:cert_required] = false
default[:murano][:ssl][:ca_certs] = "/etc/murano/ssl/certs/ca.pem"
