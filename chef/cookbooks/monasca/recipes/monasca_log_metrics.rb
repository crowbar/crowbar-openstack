#
# Cookbook Name:: monasca
# Recipe:: monasca-log-metrics
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

package "openstack-monasca-log-metrics"

monasca_node = search(:node, "roles:monasca-server")[0]
monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_node)

template "/etc/monasca-log-metrics/monasca-log-metrics.conf" do
  source "monasca-log-metrics.conf.erb"
  owner node[:monasca][:log_metrics][:user]
  group node[:monasca][:log_metrics][:group]
  mode "0640"
  variables(
    zookeeper_hosts: monasca_net_ip,
    kafka_hosts: "#{monasca_net_ip}:#{node[:monasca][:kafka][:port]}"
  )
  notifies :restart, "service[openstack-monasca-log-metrics]"
end

service "openstack-monasca-log-metrics" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end
