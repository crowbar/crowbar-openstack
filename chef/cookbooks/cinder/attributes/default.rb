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

unless node[:platform] == "suse"
  override[:cinder][:user]="cinder"
  override[:cinder][:group]="cinder"
else
  override[:cinder][:user]="openstack-cinder"
  override[:cinder][:group]="openstack-cinder"
end

# declare what needs to be monitored
node[:cinder][:monitor]={}
node[:cinder][:monitor][:svcs] = []
node[:cinder][:monitor][:ports]={}

default[:cinder][:api][:protocol] = "http"

default[:cinder][:ssl][:certfile] = "/etc/cinder/ssl/certs/signing_cert.pem"
default[:cinder][:ssl][:keyfile] = "/etc/cinder/ssl/private/signing_key.pem"
default[:cinder][:ssl][:generate_certs] = false
default[:cinder][:ssl][:insecure] = false
default[:cinder][:ssl][:cert_required] = false
default[:cinder][:ssl][:ca_certs] = "/etc/cinder/ssl/certs/ca.pem"
