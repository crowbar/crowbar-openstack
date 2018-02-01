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

neutron = nil
if node.attribute?(:cookbook) && node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' \
                                    for nova not found")
else
  neutron = node
end

ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]
ml2_type_drivers = neutron[:neutron][:ml2_type_drivers]

return unless ml2_mech_drivers.include?("nuage")

if node.roles.include?("neutron-network")
  # Explicitly stop and disable l2, l3 and metadata agents if Nuage is
  # enabled on network node
  service node[:neutron][:platform][:dhcp_agent_name] do
    action [:stop, :disable]
  end

  service node[:neutron][:platform][:metadata_agent_name] do
    action [:stop, :disable]
  end

  service node[:neutron][:platform][:l3_agent_name] do
    action [:stop, :disable]
  end

  service node[:neutron][:platform][:metering_agent_name] do
    action [:stop, :disable]
  end

  service node[:neutron][:platform][:ovs_agent_name] do
    action [:stop, :disable]
  end
end

if node.roles.include?("neutron-server")
  node[:neutron][:platform][:nuage_vsp_pkgs].each { |p| package p }
end

template neutron[:neutron][:nuage_config_file] do
  cookbook "neutron"
  source "nuage.conf.erb"
  mode "0640"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
    nuage_config: node[:neutron][:nuage]
  )
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end
