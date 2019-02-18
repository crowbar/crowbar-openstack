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

cookbook_file "#{node[:octavia][:octavia_client_cert]}" do
  source "serverca_01.pem"
  owner "octavia"
  group "octavia"
  mode 0600
  #notifies :restart, "service[openstack-octavia-worker]"
  #notifies :restart, "service[openstack-octavia-amphora-agent]"
end

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

template "/etc/octavia/octavia-worker.conf" do
  source "octavia-api.conf.erb"
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
    octavia_ca_certificate: "/etc/ssl/certs/octavia-cacert.pem",
    octavia_ca_private_key: "/etc/ssl/private/octavia-cakey.pem",
    octavia_ca_private_key_passphrase: "foobar",
    octavia_client_cert: "/etc/ssl/private/octavia-client.pem",
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

service "octavia-amphora-agent" do
  service_name "openstack-octavia-amphora-agent"
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: "/etc/octavia/amphora-agent.conf")
 # provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
