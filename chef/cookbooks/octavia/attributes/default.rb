# Copyright (c) 2019 SUSE Linux GmbH.
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
default[:octavia][:user] = "octavia"
default[:octavia][:group] = "octavia"

default[:octavia][:octavia_log_dir] = "/var/log/octavia"
default[:octavia][:octavia_bin_dir] = "octavia" # TODO: Check this value!
default[:octavia][:restart_hold] = "100ms"

default[:octavia][:debug] = false

default[:octavia][:api][:port] = 9876
default[:octavia][:api][:protocol] = "http"
default[:octavia][:api][:host] = "0.0.0.0"

default[:octavia][:db][:user] = "octavia"
default[:octavia][:db][:database] = "octavia"
default[:octavia][:db][:password]= nil

default[:octavia][:oslo][:rpc_thread_pool_size] = 2
default[:octavia][:networking][:port_detach_timeout] = 900

default[:octavia][:sudoers_file] = "/etc/sudoers.d/octavia"

default[:octavia][:certs][:country] = "US"
default[:octavia][:certs][:province] = "Oregon"
default[:octavia][:certs][:domain] = "example.com"
default[:octavia][:certs][:cert_path] = "/etc/octavia/certs/"
default[:octavia][:certs][:passphrase] = "foobar"

default[:octavia][:certs][:server_ca_cert_path] = "server_ca/certs/ca.cert.pem"
default[:octavia][:certs][:server_ca_key_path] = "server_ca/private/ca.key.pem"
default[:octavia][:certs][:client_ca_cert_path] = "client_ca/certs/ca.cert.pem"
default[:octavia][:certs][:client_cert_and_key_path] = "client_ca/private/client.cert-and-key.pem"

default[:octavia][:tmp][:node_list] = nil

default[:octavia][:amphora][:flavor] = "m1.lbaas.amphora"
default[:octavia][:amphora][:sec_group] = "lb-mgmt-sec-group"
default[:octavia][:amphora][:manage_net] = "fixed"
default[:octavia][:amphora][:image_tag] = "amphora"
default[:octavia][:amphora][:project] = "service"
