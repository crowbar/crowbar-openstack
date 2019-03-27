# Copyright 2019, SUSE Linux GmbH
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

define :octavia_conf do
  if params[:name] == "api"
    conf = "/etc/octavia/octavia.conf"
  else
    conf = "/etc/octavia/octavia-#{params[:name]}.conf"
  end

  net_name = node[:octavia][:amphora][:manage_net]

  sec_group_id = shell_out("source /root/.openrc &&"\
                            "openstack security group show #{node[:octavia][:amphora][:sec_group]}"\
                            "| tr -d ' ' | grep '|id|' | cut -f 3 -d '|'"
                          ).stdout

  flavor_id = shell_out("source /root/.openrc && openstack flavor list"\
                        "| grep #{node[:octavia][:amphora][:flavor]}"\
                        "| tr -d ' ' | cut -f 2 -d '|'"
                        ).stdout

  net_id = shell_out("source /root/.openrc && openstack network list"\
                     "| grep #{net_name} | tr -d ' ' | cut -d '|' -f 2").stdout

  list = search(:node, "roles:octavia-health-manager") || []

  hm_port = node[:octavia]["health_manager"][:port]
  hm_node_list = []
  list.each do |e|
    address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(e, net_name).address
    str = address + ":" + hm_port.to_s
    hm_node_list << str unless hm_node_list.include?(str)
  end

  neutron = node_search_with_cache("roles:neutron-server").first
  neutron_protocol = neutron[:neutron][:api][:protocol]
  neutron_server_host = CrowbarHelper.get_host_for_admin_url(
    neutron, neutron[:neutron][:ha][:server][:enabled])
  neutron_server_port = neutron[:neutron][:api][:service_port]
  neutron_endpoint = neutron_protocol + "://" + neutron_server_host + ":" + neutron_server_port.to_s

  nova = node_search_with_cache("roles:nova-controller").first
  nova_protocol = nova[:nova][:ssl][:enabled] ? "https" : "http"
  nova_server_host = CrowbarHelper.get_host_for_admin_url(nova, nova[:nova][:ha][:enabled])
  nova_server_port = nova[:nova][:ports][:api]
  nova_endpoint = nova_protocol + "://" + nova_server_host + ":" + nova_server_port.to_s + "/v2.1"

  template conf do
    source "octavia.conf.erb"
    owner node[:octavia][:user]
    group node[:octavia][:group]
    mode 0o640
    variables(
      octavia_db_connection: fetch_database_connection_string(node[:octavia][:db]),
      neutron_endpoint: neutron_endpoint,
      nova_endpoint: nova_endpoint,
      #neutron_keystone_settings: KeystoneHelper.keystone_settings(node, "neutron"),
      octavia_keystone_settings: KeystoneHelper.keystone_settings(node, "octavia"),
      rabbit_settings: fetch_rabbitmq_settings,
      octavia_nova_flavor_id: flavor_id,
      octavia_mgmt_net_id: net_id,
      octavia_mgmt_sec_group_id: sec_group_id,
      octavia_healthmanager_hosts: hm_node_list.join(",")
    )
  end
end
