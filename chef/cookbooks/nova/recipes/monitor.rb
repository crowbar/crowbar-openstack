#
# Copyright 2011, Dell
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
# Author: Greg Althaus
#

####
# if monitored by nagios, install the nrpe commands

return unless node["roles"].include?("nagios-client")

include_recipe "nagios::common"

# Nova scale data holder
nova_scale = {
  computes: [],
  schedulers: []
}

search_env_filtered(:node, "roles:nova-controller") do |n|
  nova_scale[:schedulers] << n
end

search_env_filtered(:node, "roles:nova-compute-docker") do |n|
  nova_scale[:computes] << n
end

search_env_filtered(:node, "roles:nova-compute-hyperv") do |n|
  nova_scale[:computes] << n
end

search_env_filtered(:node, "roles:nova-compute-kvm") do |n|
  nova_scale[:computes] << n
end

search_env_filtered(:node, "roles:nova-compute-qemu") do |n|
  nova_scale[:computes] << n
end

search_env_filtered(:node, "roles:nova-compute-vmware") do |n|
  nova_scale[:computes] << n
end

search_env_filtered(:node, "roles:nova-compute-xen") do |n|
  nova_scale[:computes] << n
end

search_env_filtered(:node, "roles:nova-compute-zvm") do |n|
  nova_scale[:computes] << n
end

nova_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
template "/etc/nagios/nrpe.d/nova_nrpe.cfg" do
  source "nova_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables(
    nova_scale: nova_scale,
    nova_admin_ip: nova_admin_ip
  )
  notifies :restart, "service[nagios-nrpe-server]"
end

template "/etc/sudoers.d/nagios_sudoers" do
  source "nagios_sudoers.erb"
  mode "0440"
  group "root"
  owner "root"
end
