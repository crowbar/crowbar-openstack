#
# Copyright 2016 SUSE
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

# Install NSDB. This should be done on dedicated database nodes. For now the
# installation is on neutron-server nodes.

node[:neutron][:platform][:midonet_nsdb_pkgs].each { |p| package p }

# Map NSDB nodes to neutron-server nodes. Eventually we could create a new
# role (nsdb-server).
zookeeper_hosts = node_search_with_cache("roles:neutron-server") || []
zookeeper_hosts = zookeeper_hosts.map do |h|
  Barclamp::Inventory.get_network_by_type(h, "admin").address
end
zookeeper_host_list_with_ports = zookeeper_hosts.map do |h|
  h + ":2181"
end
zookeeper_host_list_with_ports = zookeeper_host_list_with_ports.join(",")

if zookeeper_hosts.length < 3
  Chef::Log.warn("MidoNet: Please configure at least 3 zookeeper nodes for " \
                 "failover redundancy and an odd number for best " \
                 "performance.")
end

template "/etc/zookeeper/zoo.cfg" do
  source "zoo.cfg.erb"
  owner "zookeeper"
  group "zookeeper"
  mode 0o640
  variables(
    zookeeper_hosts: zookeeper_hosts,
    snapRetainCount: node[:neutron][:midonet][:zookeeper][:snapRetainCount],
    purgeInterval: 12
  )
end

utils_systemd_environment "zookeeper" do
  service_name "zookeeper"
  environment node[:neutron][:midonet][:zookeeper][:environment]
end

service "zookeeper" do
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, "template[/etc/zookeeper/zoo.cfg]", :delayed
end

utils_systemd_environment "cassandra" do
  service_name "cassandra"
  environment node[:neutron][:midonet][:cassandra][:environment]
end

service "cassandra" do
  supports status: true, restart: true
  action [:enable, :start]
end

template "/etc/cassandra/conf/cassandra.yaml" do
  source "cassandra.yaml.erb"
  owner "cassandra"
  group "cassandra"
  mode 0o640
  variables(
    zookeeper_hosts: zookeeper_hosts,
    ip_address: Barclamp::Inventory.get_network_by_type(node, "admin").address
  )
  notifies :restart, "service[cassandra]"
end
