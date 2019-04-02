# Copyright 2019, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

define :octavia_conf do
  cmd = params[:cmd]
  network_settings = OctaviaHelper.network_settings(node)

  if params[:name] == "api"
    conf = "/etc/octavia/octavia.conf"
    bind_host = network_settings[:api][:bind_host]
    bind_port = network_settings[:api][:bind_port]
  else
    conf = "/etc/octavia/octavia-#{params[:name]}.conf"
    bind_host = network_settings[:health_manager][:bind_host]
    bind_port = network_settings[:health_manager][:bind_port]
  end

  net_name = node[:octavia][:amphora][:manage_net]["name"]
  sec_group_id = shell_out("#{cmd} security group show #{node[:octavia][:amphora][:sec_group]} "\
                           "-f value -c id").stdout
  flavor_id = shell_out("#{cmd} flavor show #{node[:octavia][:amphora][:flavor]} "\
                           "-f value -c id").stdout
  net_id = shell_out("#{cmd} network show #{net_name} -f value -c id").stdout

  template conf do
    source "octavia.conf.erb"
    owner node[:octavia][:user]
    group node[:octavia][:group]
    mode 0o640
    variables(
      bind_host: bind_host,
      bind_port: bind_port,
      octavia_db_connection: fetch_database_connection_string(node[:octavia][:db]),
      neutron_endpoint: OctaviaHelper.get_neutron_endpoint(node),
      nova_endpoint: OctaviaHelper.get_nova_endpoint(node),
      octavia_keystone_settings: KeystoneHelper.keystone_settings(node, "octavia"),
      rabbit_settings: fetch_rabbitmq_settings,
      octavia_nova_flavor_id: flavor_id,
      octavia_mgmt_net_id: net_id,
      octavia_mgmt_sec_group_id: sec_group_id,
      octavia_healthmanager_hosts: OctaviaHelper.get_healthmanager_nodes(node, net_name).join(",")
    )
  end
end
