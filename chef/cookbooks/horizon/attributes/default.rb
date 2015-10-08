# Copyright 2011, Dell, Inc., Inc.
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

default[:horizon][:db][:database] = "horizon"
default[:horizon][:db][:user] = "horizon"
default[:horizon][:db][:password] = nil # must be set by wrapper

default[:horizon][:debug] = false
default[:horizon][:site_branding] = "OpenStack Dashboard"
default[:horizon][:site_theme] = ""
default[:horizon][:site_branding_link] = ""
default[:horizon][:help_url] = "http://docs.openstack.org/"

default[:horizon][:policy_file_path] = ""

default[:horizon][:policy_file][:identity] = "keystone_policy.json"
default[:horizon][:policy_file][:compute] = "nova_policy.json"
default[:horizon][:policy_file][:volume] = "cinder_policy.json"
default[:horizon][:policy_file][:image] = "glance_policy.json"
default[:horizon][:policy_file][:orchestration] = "heat_policy.json"
default[:horizon][:policy_file][:network] = "neutron_policy.json"
default[:horizon][:policy_file][:telemetry] = "ceilometer_policy.json"

default[:horizon][:apache][:ssl] = false
default[:horizon][:apache][:ssl_crt_file] = "/etc/apache2/ssl.crt/openstack-dashboard-server.crt"
default[:horizon][:apache][:ssl_key_file] = "/etc/apache2/ssl.key/openstack-dashboard-server.key"
default[:horizon][:apache][:ssl_crt_chain_file] = ""

default[:horizon][:ha][:enabled] = false
# Ports to bind to when haproxy is used for the real ports
default[:horizon][:ha][:ports][:plain] = 5580
default[:horizon][:ha][:ports][:ssl] = 5581

# declare what needs to be monitored
node[:horizon][:monitor] = {}
node[:horizon][:monitor][:svcs] = []
node[:horizon][:monitor][:ports] = {}

default["horizon"]["can_set_mount_point"] = false
# Display password fields for Nova password injection
default["horizon"]["can_set_password"] = false

# Display "Domain" text field on login page
default[:horizon][:multi_domain_support] = false

# Set as false when using PKI tokens (401 errors)
default[:horizon][:token_hash_enabled] = true
