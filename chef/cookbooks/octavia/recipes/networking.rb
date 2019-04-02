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

net_name = node[:octavia][:amphora][:manage_net]["name"]
octavia_subnet = node[:octavia][:amphora][:manage_net][:subnet]
octavia_mask = node[:octavia][:amphora][:manage_net][:netmask]
octavia_range = "#{octavia_subnet}/#{mask_to_bits(octavia_mask)}"
octavia_pool_start = node[:octavia][:amphora][:manage_net][:pool_start]
octavia_pool_end = node[:octavia][:amphora][:manage_net][:pool_end]

execute "create_octavia_network" do
  command "#{cmd} network create --share #{net_name}"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  not_if "out=$(#{cmd} network list); [ $? != 0 ] || echo ${out} | grep -q ' #{net_name} '"
  retries 5
  retry_delay 10
  action :run
end

execute "create_octavia_subnet" do
  command "#{cmd} subnet create --network #{net_name} --ip-version=4 " \
      "--allocation-pool start=#{octavia_pool_start},end=#{octavia_pool_end} " \
      "--subnet-range #{octavia_range} --dhcp #{net_name}"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  not_if "out=$(#{cmd} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' #{net_name} '"
  retries 5
  retry_delay 10
  action :run
end
