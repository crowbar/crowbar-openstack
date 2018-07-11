# Copyright 2018, SUSE Linux GmbH
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

default[:designate][:debug] = false
override[:designate][:user] = "designate"
override[:designate][:group] = "designate"
default[:designate][:max_header_line] = 16384
default[:designate][:api][:protocol] = "http"
default[:designate][:api][:bind_port] = 9001
default[:designate][:use_syslog] = false
default[:designate][:config_file] = "/etc/designate/designate.conf.d/100-designate.conf"

default[:designate][:ha][:enabled] = false
# Ports to bind to when haproxy is used for the real ports
default[:designate][:ha][:ports][:api_port] = 5574

default[:designate][:ha][:api][:ra] = if ["rhel", "suse"].include? node[:platform_family]
  "systemd:openstack-designate-api"
else
  "systemd:designate-api"
end

default[:designate][:ha][:op][:monitor][:interval] = "10s"
