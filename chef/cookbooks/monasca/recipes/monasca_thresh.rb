#
# Cookbook Name:: monasca
# Recipe:: monasca_thresh
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

package "openstack-monasca-thresh"

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers).sort!

db_settings = fetch_database_settings

template "/etc/monasca-thresh/thresh.yaml" do
  source "monasca-thresh-config.yaml.erb"
  owner node[:monasca][:thresh][:user]
  group node[:monasca][:thresh][:group]
  mode "0640"
  variables(
    zookeeper_hosts: monasca_hosts,
    kafka_host: monasca_hosts[0],
    database_host: db_settings[:address]
  )
  notifies :restart, "service[openstack-monasca-thresh]"
end

service "openstack-monasca-thresh" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end
