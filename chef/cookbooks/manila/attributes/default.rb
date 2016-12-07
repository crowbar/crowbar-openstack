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

default[:manila][:debug] = false

override[:manila][:user] = "manila"
override[:manila][:group] = "manila"

default[:manila][:max_header_line] = 16384

default[:manila][:api][:protocol] = "http"

# HA attributes
default[:manila][:ha][:enabled] = false
if %w(rhel suse).include? node[:platform_family]
  default[:manila][:ha][:api_ra] = "systemd:openstack-manila-api"
  default[:manila][:ha][:scheduler_ra] = "systemd:openstack-manila-scheduler"
  default[:manila][:ha][:share_ra] = "systemd:openstack-manila-share"
else
  default[:manila][:ha][:api_ra] = "systemd:manila-api"
  default[:manila][:ha][:scheduler_ra] = "systemd:manila-scheduler"
  default[:manila][:ha][:share_ra] = "systemd:manila-share"
end
default[:manila][:ha][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:manila][:ha][:ports][:api] = 5525

default[:manila][:ssl][:certfile] = "/etc/manila/ssl/certs/signing_cert.pem"
default[:manila][:ssl][:keyfile] = "/etc/manila/ssl/private/signing_key.pem"
default[:manila][:ssl][:generate_certs] = false
default[:manila][:ssl][:insecure] = false
default[:manila][:ssl][:cert_required] = false
default[:manila][:ssl][:ca_certs] = "/etc/manila/ssl/certs/ca.pem"
