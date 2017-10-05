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

elements = node[:nova][:elements_expanded] || node[:nova][:elements]

nova_controllers_n = elements["nova-controller"].length
nova_computes_n = 0

compute_roles = elements.keys.select { |r| r =~ /^nova-compute-/ }
compute_roles.each do |role|
  nova_computes_n += elements[role].length
end

nova_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
template "/etc/nagios/nrpe.d/nova_nrpe.cfg" do
  source "nova_nrpe.cfg.erb"
  mode "0644"
  group node[:nagios][:group]
  owner node[:nagios][:user]
  variables(
    nova_controllers_n: nova_controllers_n,
    nova_computes_n: nova_computes_n,
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
