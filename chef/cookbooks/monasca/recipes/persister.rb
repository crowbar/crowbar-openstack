#
# Copyright 2017 SUSE Linux GmbH
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

monasca_server = node_search_with_cache("roles:monasca-server").first
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found. Skip monasca-persister setup.")
  return
end

package "openstack-monasca-persister"

monasca_net_ip = MonascaHelper.get_host_for_monitoring_url(monasca_server)

# write monasca-persister config
template "/etc/monasca/persister.conf" do
  source "monasca-persister.conf.erb"
  owner "monasca-persister"
  group "monasca"
  mode "0640"
  variables(
    debug: node[:monasca][:debug],
    log_dir: "/var/log/monasca-persister/",
    influxdb_host: monasca_net_ip,
    influxdb_port: "8086",
    influxdb_database_name: "mon",
    influxdb_username: "mon_api",
    influxdb_mon_persister_password: node[:monasca][:master][:influxdb_mon_persister_password],
    zookeeper_hosts: monasca_net_ip,
    kafka_hosts: "#{monasca_net_ip}:9092"
  )
end

# enable and start the monasca-persister
service "openstack-monasca-persister" do
  service_name "openstack-monasca-persister"
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  subscribes :restart, resources(template: "/etc/monasca/persister.conf")
end
