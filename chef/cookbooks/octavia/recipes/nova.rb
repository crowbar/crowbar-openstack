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

require "chef/mixin/shell_out"

package "openstack-octavia-amphora-image-x86_64"

ha_enabled = node[:octavia][:ha][:enabled]
octavia_config = Barclamp::Config.load("openstack", "octavia")
cmd = OctaviaHelper.get_openstack_command(node, octavia_config)

sec_group = node[:octavia][:amphora][:sec_group]
project_name = node[:octavia][:amphora][:project]

execute "create_security_group" do
  command "#{cmd} security group create #{sec_group} --project #{project_name} "\
    "--description \"Octavia Management Security Group\""
  not_if "out=$(#{cmd} security group list); [ $? != 0 ] || echo ${out} | grep -q ' #{sec_group} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "add_amphora_port_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol tcp --dst-port 9443:9443 #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'9443'\""
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "add_ssh_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol tcp --dst-port 22:22 #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'22'\""
  only_if { node[:octavia][:amphora][:ssh_access] }
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

execute "add_icmp_to_amphora_security_group" do
  command "#{cmd} security group rule create --protocol icmp #{sec_group}"
  not_if "out=$(#{cmd} security group show #{sec_group}); [ $? != 0 ] || echo ${out} | " \
    "grep -q \"'icmp'\""
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

flavor = node[:octavia][:amphora][:flavor]

execute "create_amphora_flavor" do
  command "#{cmd} flavor create --public --ram 1024 --disk 2 --vcpus 1 #{flavor}"
  not_if "out=$(#{cmd} flavor list); [ $? != 0 ] || echo ${out} | grep -q ' #{flavor} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end

package = "openstack-octavia-amphora-image-x86_64"
image_tag = node[:octavia][:amphora][:image_tag]

execute "create_amphora_image" do
  command "#{cmd} image create --disk-format qcow2 --container-format bare "\
    "--file $(rpm -ql #{package} | grep qcow2 | head -n 1) --tag #{image_tag} #{image_tag}"
  not_if "out=$(#{cmd} image list); [ $? != 0 ] || echo ${out} | grep -q ' #{image_tag} '"
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  retries 5
  retry_delay 10
  action :run
end
