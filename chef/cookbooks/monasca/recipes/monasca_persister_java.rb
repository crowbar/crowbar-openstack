#
# Cookbook Name:: monasca
# Recipe:: monasca_persister_java
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

package "openstack-monasca-persister-java"

monasca_servers = node_search_with_cache("roles:monasca-server")
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_servers[0])

template "/etc/monasca-persister/monasca-persister.yaml" do
  source "monasca-persister-java.yaml.erb"
  owner node[:monasca][:persister][:user]
  group node[:monasca][:persister][:group]
  mode "0640"
  variables(
    zookeeper_host: monasca_net_ip,
    cassandra_hosts: monasca_net_ip
  )
  notifies :restart, "service[openstack-monasca-persister]"
end

service "openstack-monasca-persister" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end
