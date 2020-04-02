# Copyright 2019 SUSE LLC.
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

cmd = OctaviaHelper.get_openstack_command(node, node[:octavia])

ruby_block "Check for amphora changes" do
  block do
    amphora = node[:octavia][:amphora]
    sec_group_id = shell_out("#{cmd} security group show " \
                             "#{amphora[:sec_group]} -f value -c id").stdout.chomp
    flavor_id = shell_out("#{cmd} flavor show "\
                          "#{amphora[:flavor]} -f value -c id").stdout.chomp
    mgmt_net_id = shell_out("#{cmd} network list " \
                            "--format value --column ID --column Name " \
                            "| grep #{amphora[:manage_net]} | cut -d ' ' -f 1").stdout.chomp

    sec_group_id.empty? || node.set[:octavia][:sec_group_id] = sec_group_id
    flavor_id.empty? || node.set[:octavia][:flavor_id] = flavor_id
    mgmt_net_id.empty? || node.set[:octavia][:net_id] = mgmt_net_id
  end
end

octavia_conf "worker"
octavia_service "worker"
