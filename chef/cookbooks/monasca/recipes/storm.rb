#
# Cookbook Name:: monasca
# Recipe:: storm
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

["storm", "storm-nimbus", "storm-supervisor"].each do |p|
  package p do
    action :install
  end
end

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers).sort!


template "/etc/storm/storm.yaml" do
  source "storm-storm.yaml.erb"
  owner node[:monasca][:storm][:user]
  group node[:monasca][:storm][:group]
  mode "0640"
  variables(
    zookeeper_hosts: [monasca_hosts[0]],
    storm_master_hosts: [monasca_hosts[0]]
  )
  notifies :restart, "service[storm-nimbus]"
  notifies :restart, "service[storm-supervisor]"
end

service "storm-nimbus" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end

service "storm-supervisor" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end
