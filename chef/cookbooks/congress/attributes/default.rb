# Copyright 2015, SUSE, Inc.
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

default[:congress][:debug] = false

override[:congress][:user] = "congress"
override[:congress][:group] = "congress"

default[:congress][:max_header_line] = 16384

default[:congress][:api][:protocol] = "http"

# HA attributes
default[:congress][:ha][:enabled] = false
if %w(rhel suse).include? node[:platform_family]
  default[:congress][:ha][:api_ra] = "lsb:openstack-congress-server"
else
  default[:congress][:ha][:api_ra] = "lsb:congress-server"
end
default[:congress][:ha][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:congress][:ha][:ports][:api] = 5525
