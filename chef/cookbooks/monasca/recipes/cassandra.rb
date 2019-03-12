#
# Cookbook Name:: monasca
# Recipe:: cassandra
#
# Copyright 2019, SUSE Linux GmbH.
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

package "cassandra"

monasca_node = node_search_with_cache("roles:monasca-server").first
monasca_monitoring_host =
  Chef::Recipe::Barclamp::Inventory.get_network_by_type(
    monasca_node, node[:monasca][:network]
  ).address

template "/etc/cassandra/conf/cassandra.yaml" do
  source "cassandra.yaml.erb"
  owner node[:monasca][:cassandra][:user]
  group node[:monasca][:cassandra][:group]
  mode "0640"
  variables(
    broadcast_rpc_address: monasca_monitoring_host
  )
  notifies :restart, "service[cassandra]"
end

service "cassandra" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end
