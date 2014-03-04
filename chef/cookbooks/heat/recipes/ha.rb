# Copyright 2014 SUSE
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

haproxy_servers, haproxy_servers_nodes  = PacemakerHelper.haproxy_servers(node, "heat-server")
haproxy_servers.each do |haproxy_server|
  haproxy_server_node = haproxy_servers_nodes[haproxy_server['name']]
  haproxy_server['address'] = Chef::Recipe::Barclamp::Inventory.get_network_by_type(haproxy_server_node, "admin").address
  haproxy_server['port'] = haproxy_server_node[:heat][:ha][:ports][:api_port]
end

haproxy_loadbalancer "heat-api" do
  address "0.0.0.0"
  port node[:heat][:api][:port]
  use_ssl (node[:heat][:api][:protocol] == "https")
  servers haproxy_servers
  action :nothing
end.run_action(:create)

haproxy_api_cfn_servers = haproxy_servers.map{|s| s.clone}
haproxy_api_cfn_servers.each do |haproxy_server|
  haproxy_server_node = haproxy_servers_nodes[haproxy_server['name']]
  # No need to set address, as we cloned the previous list with the right address
  haproxy_server['port'] = haproxy_server_node[:heat][:ha][:ports][:cfn_port]
end

haproxy_loadbalancer "heat-api-cfn" do
  address "0.0.0.0"
  port node[:heat][:api][:cfn_port]
  use_ssl (node[:heat][:api][:protocol] == "https")
  servers haproxy_api_cfn_servers
  action :nothing
end.run_action(:create)

haproxy_api_cloud_watch_servers = haproxy_servers.map{|s| s.clone}
haproxy_api_cloud_watch_servers.each do |haproxy_server|
  haproxy_server_node = haproxy_servers_nodes[haproxy_server['name']]
  # No need to set address, as we cloned the previous list with the right address
  haproxy_server['port'] = haproxy_server_node[:heat][:ha][:ports][:cloud_watch_port]
end

haproxy_loadbalancer "heat-api-cloudwatch" do
  address "0.0.0.0"
  port node[:heat][:api][:cloud_watch_port]
  use_ssl (node[:heat][:api][:protocol] == "https")
  servers haproxy_api_cloud_watch_servers
  action :nothing
end.run_action(:create)

# TODO pacemaker part for heat-engine
