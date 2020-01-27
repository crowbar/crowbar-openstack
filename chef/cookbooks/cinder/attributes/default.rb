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

default[:cinder][:debug] = false
default[:cinder][:verbose] = false
default[:cinder][:max_header_line] = 16384
default[:cinder][:config_file] = "/etc/cinder/cinder.conf.d/100-cinder.conf"
default[:cinder][:config_file_cinder_volume] = "/etc/cinder/cinder-volume.conf.d/100-cinder-volume.conf"

override[:cinder][:user]="cinder"
override[:cinder][:group]="cinder"

# declare what needs to be monitored
default[:cinder][:monitor] = {}
default[:cinder][:monitor][:svcs] = []
default[:cinder][:monitor][:ports] = {}

default[:cinder][:api][:protocol] = "http"

default[:cinder][:ssl][:certfile] = "/etc/cinder/ssl/certs/signing_cert.pem"
default[:cinder][:ssl][:keyfile] = "/etc/cinder/ssl/private/signing_key.pem"
default[:cinder][:ssl][:generate_certs] = false
default[:cinder][:ssl][:insecure] = false
default[:cinder][:ssl][:cert_required] = false
default[:cinder][:ssl][:ca_certs] = "/etc/cinder/ssl/certs/ca.pem"

#sqlalchemy parameters
default[:cinder][:max_pool_size] = 30
default[:cinder][:max_overflow] = 10
default[:cinder][:pool_timeout] = 30

default[:cinder][:ha][:enabled] = false
if %w(rhel suse).include? node[:platform_family]
  default[:cinder][:ha][:api_ra] = "systemd:openstack-cinder-api"
  default[:cinder][:ha][:scheduler_ra] = "systemd:openstack-cinder-scheduler"
  default[:cinder][:ha][:volume_ra] = "systemd:openstack-cinder-volume"
else
  default[:cinder][:ha][:api_ra] = "systemd:cinder-api"
  default[:cinder][:ha][:scheduler_ra] = "systemd:cinder-scheduler"
  default[:cinder][:ha][:volume_ra] = "systemd:cinder-volume"
end
default[:cinder][:ha][:op][:monitor][:interval] = "10s"
# Ports to bind to when haproxy is used for the real ports
default[:cinder][:ha][:ports][:api] = 5520

#
# SSL settings
#
default[:cinder][:ssl][:loadbalancer_terminate_ssl] = false
default[:cinder][:ssl][:pemfile] = "/etc/ssl/private/cinder.pem"
