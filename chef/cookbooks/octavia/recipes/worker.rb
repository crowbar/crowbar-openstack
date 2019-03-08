# Copyright 2019 SUSE Linux GmbH.
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

sec_group_id = shell_out("source /root/.openrc &&"\
                          "openstack security group show #{node[:octavia][:amphora][:sec_group]}"\
                          "| tr -d ' ' | grep '|id|' | cut -f 3 -d '|'"
                        ).stdout

flavor_id = shell_out("source /root/.openrc && openstack flavor list"\
                      "| grep #{node[:octavia][:amphora][:flavor]}"\
                      "| tr -d ' ' | cut -f 2 -d '|'"
                      ).stdout

net_id = shell_out("source /root/.openrc && openstack network list"\
                   "| grep #{node[:octavia][:amphora][:manage_net]} | tr -d ' ' | cut -d '|' -f 2"
                  ).stdout

template "/etc/octavia/octavia-worker.conf" do
  source "octavia-worker.conf.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 0o640
  variables(
    octavia_db_connection: fetch_database_connection_string(node[:octavia][:db]),
    neutron_keystone_settings: KeystoneHelper.keystone_settings(node, "neutron"),
    octavia_keystone_settings: KeystoneHelper.keystone_settings(node, "octavia"),
    octavia_nova_flavor_id: flavor_id,
    octavia_mgmt_net_id: net_id,
    octavia_mgmt_sec_group_id: sec_group_id
  )
end

file node[:octavia][:octavia_log_dir] + "/octavia-worker.log" do
  action :touch
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 0o640
end

octavia_service "worker"
