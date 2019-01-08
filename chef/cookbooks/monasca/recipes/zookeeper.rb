#
# Cookbook Name:: monasca
# Recipe:: zookeeper
#
# Copyright 2018, SUSE Linux GmbH.
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

package "zookeeper-server"

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers).sort!

template "/etc/zookeeper/zoo.cfg" do
  source "zookeeper-zoo.cfg.erb"
  owner "zookeeper"
  group "zookeeper"
  mode "0640"
  variables(
    zookeeper_data_dir: node[:monasca][:zookeeper][:data_dir],
    zookeeper_client_port_address: node[:monasca][:zookeeper][:client_port_address],
    zookeeper_client_port: node[:monasca][:zookeeper][:client_port],
    zookeeper_hosts: [monasca_hosts[0]]
  )
  notifies :restart, "service[zookeeper]"
end

template "#{node[:monasca][:zookeeper][:data_dir]}/myid" do
  source "zookeeper-myid.erb"
  owner "zookeeper"
  group "zookeeper"
  mode "0640"
  variables(
    # FIXME: This should be the same ID as in zoo.cfg . This currently works
    # because we allow just a single host!
    zookeeper_myid: 1
  )
  notifies :restart, "service[zookeeper]"
end

service "zookeeper" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end
