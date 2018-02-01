#
# Copyright 2018 SUSE Linux GmBH
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

# install nuage VRS
node[:neutron][:platform][:nuage_vrs_pkgs].each { |p| package p }

# Nuage missed one dependency in their ovs package. Adding it here
packages = ["python-setproctitle"]
packages.each do |pkg|
  package pkg do
    action :install
  end
end

if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
else
  neutron = node
end

template "/etc/default/openvswitch" do
  source "nuage_openvswitch.erb"
  owner "root"
  group "root"
  mode "0640"
  variables(
    nuage_config: neutron[:neutron][:nuage]
  )
end

service "openvswitch" do
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/default/openvswitch]")
end

if node.roles.include?("nova-compute-kvm") or 
   node.roles.include?("nova-compute-qemu")
  packages = ["python-novaclient"]
  packages.each do |pkg|
    package pkg do
      action :install
    end
  end

  node[:neutron][:platform][:nuage_vrs_metadata_pkgs].each { |p| package p }

  keystone_settings = KeystoneHelper.keystone_settings(node, :nova)
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

  template "/etc/default/nuage-metadata-agent" do
    source "nuage_metadata_agent.erb"
    owner "root"
    group node[:nova][:group]
    mode "0640"
    variables(
      nuage_config: neutron[:neutron][:nuage],
      keystone_settings: keystone_settings,
      metadata_bind_address: admin_address,
      metadata_port: 9697,
      nova_metadata_port: node[:nova][:ports][:metadata]
    )
    notifies :restart, "service[openvswitch]"
  end
end

