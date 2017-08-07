# Copyright 2016, SUSE Linux GmbH
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

default[:sahara][:debug] = false
override[:sahara][:user] = "sahara"
override[:sahara][:group] = "sahara"
default[:sahara][:max_header_line] = 16384
default[:sahara][:api][:protocol] = "http"
default[:sahara][:api][:bind_port] = 8386
default[:sahara][:use_syslog] = false
default[:sahara][:config_file] = "/etc/sahara/sahara.conf.d/100-sahara.conf"

default[:sahara][:ha][:enabled] = false
# Ports to bind to when haproxy is used for the real ports
default[:sahara][:ha][:ports][:api_port] = 5573

default[:sahara][:ha][:api][:ra] = if ["rhel", "suse"].include? node[:platform_family]
  "systemd:openstack-sahara-api"
else
  "systemd:sahara-api"
end

default[:sahara][:ha][:engine][:ra] = if ["rhel", "suse"].include? node[:platform_family]
  "systemd:openstack-sahara-engine"
else
  "systemd:sahara-engine"
end

default[:sahara][:ha][:op][:monitor][:interval] = "10s"
