# Copyright 2019 SUSE Linux, GmbH.
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
Chef::Log.info "YYYY *************************************** WORKER *******************************"

neutron = node_search_with_cache("roles:neutron-server").first
neutron_protocol = neutron[:neutron][:api][:protocol]
neutron_server_host = CrowbarHelper.get_host_for_admin_url(neutron, neutron[:neutron][:ha][:server][:enabled])
neutron_server_port = neutron[:neutron][:api][:service_port]
neutron_endpoint = neutron_protocol + "://" + neutron_server_host + ":" + neutron_server_port.to_s

nova = node_search_with_cache("roles:neutron-server").first
nova_protocol = nova[:nova][:ssl][:enabled] ? "https" : "http"
nova_server_host = CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled])
nova_server_port = nova[:nova][:ports][:api]
nova_endpoint = nova_protocol + "://" + nova_server_host + ":" + nova_server_port.to_s

sec_group_id = shell_out("source /root/.openrc && openstack security group show #{node[:octavia][:amphora][:sec_group]} | tr -d ' ' | grep '|id|' | cut -f 3 -d '|'").stdout
Chef::Log.info "YYYY ----- sec_group_id #{sec_group_id}"

flavor_id = shell_out("source /root/.openrc && nova flavor-access-list --flavor #{node[:octavia][:amphora][:flavor]} | head -n -1 | tail -n +4 | tr -d ' ' | cut -f 3 -d '|'").stdout
Chef::Log.info "YYYY ----- flavor_id #{flavor_id}"

image_id = shell_out("source /root/.openrc && glance image-list | grep #{node[:octavia][:amphora][:image_tag]} | tr -d ' ' | cut -f 2 -d '|'").stdout
Chef::Log.info "YYYY ----- image_id #{image_id}"

net_id = shell_out("source /root/.openrc && openstack network list | grep fixed | tr -d ' ' | cut -d '|' -f 2").stdout
Chef::Log.info "YYYY ----- net_id #{net_id}"


template "/etc/octavia/octavia-worker.conf" do
  source "octavia-worker.conf.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
  variables(
    octavia_db_connection: OctaviaHelper.db_connection(fetch_database_settings, node),
    octavia_bind_host: "0.0.0.0",
    neutron_endpoint: neutron_endpoint,
    nova_endpoint: nova_endpoint,
    neutron_keystone_settings: KeystoneHelper.keystone_settings(node, "neutron"),
    octavia_keystone_settings: KeystoneHelper.keystone_settings(node, "octavia"),
    rabbit_settings: fetch_rabbitmq_settings,
    octavia_nova_flavor_id: flavor_id,
    octavia_amp_image_id: image_id,
    octavia_mgmt_net_id: net_id,
    octavia_mgmt_sec_group_id: sec_group_id
  )
end

file node[:octavia][:octavia_log_dir] + "/octavia-worker.log" do
  action :touch
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
end

octavia_service "worker"

package "openstack-octavia-amphora-agent"

template "/etc/octavia/amphora-agent.conf" do
  source "amphora-agent.conf.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00640
  variables(
  )
end

service "octavia-amphora-agent" do
  service_name "openstack-octavia-amphora-agent"
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: "/etc/octavia/amphora-agent.conf")
 # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
