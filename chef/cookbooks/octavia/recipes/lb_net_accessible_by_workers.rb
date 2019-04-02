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

require "ipaddr"

def mask_to_bits(mask)
  IPAddr.new(mask).to_i.to_s(2).count("1")
end

ha_enabled = node[:octavia][:ha][:enabled]
octavia_config = Barclamp::Config.load("openstack", "octavia")
cmd = OctaviaHelper.get_openstack_command(node, octavia_config)

octavia_net = node[:octavia][:amphora][:manage_net]
net_name = octavia_net[:name]
router_name = "lb-router"

octavia_range = "#{octavia_net["subnet"]}/#{mask_to_bits(octavia_net["netmask"])}"

execute "create_octavia_router" do
  command "#{cmd} router create #{router_name}"
  only_if { octavia_net }
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  not_if "out=$(#{cmd} router list); [ $? != 0 ] || echo ${out} | grep -q ' #{router_name} '"
  retries 5
  retry_delay 10
  action :run
end

execute "add_octavia_subnet_to_router" do
  command "#{cmd} router add subnet #{router_name} #{net_name}"
  only_if { octavia_net }
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  not_if "out=$(#{cmd} router show #{router_name}); [ $? != 0 ] || echo ${out} | grep -q " \
    "$(#{cmd} subnet show #{net_name} | tr -d ' ' | grep '|id|' | cut -d '|' -f 3)"
  retries 5
  retry_delay 10
  action :run
end

execute "set_octavia_set_external_gateway" do
  command "#{cmd} router set --external-gateway floating #{router_name}"
  only_if { octavia_net }
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

crowbar_pacemaker_sync_mark "sync-octavia-network-creation" if ha_enabled

ruby_block "add_octavia_network_route" do
  block do
    filter = '| tr ":" "\n" | grep -A 1 ip_address | tail -n 1 | tr -d "\"|}|]|\\\\" | tr -d " "'
    gateway_id = shell_out("#{cmd} router show #{router_name} -c external_gateway_info " \
        " -f json #{filter}").stdout

    shell_out("ip r add #{octavia_range} via #{gateway_id}")
  end
end
