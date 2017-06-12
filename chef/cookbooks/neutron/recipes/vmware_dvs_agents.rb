#
# Copyright 2017 SUSE Linux GmBH
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

package node[:neutron][:platform][:vmware_vsphere_dvs_agent_pkg]

include_recipe "neutron::common_config"

agent_config_path = "/etc/neutron/plugins/ml2/vmware_dvs_agent.ini"
agent_service_name = "openstack-neutron-dvs-agent"

template agent_config_path do
  cookbook "neutron"
  source "vmware_dvs_agent.ini.erb"
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  variables(
    vcenter_config: node[:nova][:vcenter]
  )
end

service agent_service_name do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:neutron][:config_file])
  subscribes :restart, resources(template: agent_config_path)
end
