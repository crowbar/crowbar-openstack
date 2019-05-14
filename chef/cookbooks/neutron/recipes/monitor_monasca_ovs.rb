#
# Copyright 2019 SUSE Linux GmbH
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

return unless node["roles"].include?("monasca-agent")

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:monasca][:agent][:monitor_ovs]
  node["roles"].each do |role|

    next unless node[:neutron][:ml2_mechanism_drivers].include?("openvswitch")

    monasca_agent_plugin_ovs "OVS check for neutron" do
      user_domain_name "Default"
      project_domain_name "Default"
      region_name keystone_settings["endpoint_region"]
      username keystone_settings["service_user"]
      password keystone_settings["service_password"]
      project_name keystone_settings["service_tenant"]
      auth_url keystone_settings["internal_auth_url"]
      check_router_ha node[:neutron][:l3_ha][:use_l3_ha]
    end
  end
end
