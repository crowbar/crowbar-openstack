# Copyright 2011 Dell, Inc.
# Copyright 2015 SUSE Linux GmbH
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
require "ipaddr"

def mask_to_bits(mask)
  IPAddr.new(mask).to_i.to_s(2).count("1")
end

# accessing the network definition directly, since the node is not using this
# network
fixed_net = Barclamp::Inventory.get_network_definition(node, "nova_fixed")
fixed_net_ranges = fixed_net["ranges"]
fixed_range = "#{fixed_net["subnet"]}/#{mask_to_bits(fixed_net["netmask"])}"
fixed_pool_start = fixed_net_ranges[:dhcp][:start]
fixed_pool_end = fixed_net_ranges[:dhcp][:end]
fixed_first_ip = IPAddr.new("#{fixed_range}").to_range().to_a[2]
fixed_last_ip = IPAddr.new("#{fixed_range}").to_range().to_a[-2]

fixed_pool_start = fixed_first_ip if fixed_first_ip > fixed_pool_start
fixed_pool_end = fixed_last_ip if fixed_last_ip < fixed_pool_end

public_net = Barclamp::Inventory.get_network_by_type(node, "public")
# accessing the network definition directly, since the node is not necessarily
# using this network
floating_net = Barclamp::Inventory.get_network_definition(node, "nova_floating")
floating_net_ranges = floating_net["ranges"]

public_net_addr = IPAddr.new("#{public_net.subnet}/#{public_net.netmask}")
floating_net_addr = IPAddr.new("#{floating_net["subnet"]}/#{floating_net["netmask"]}")

# For backwards compatibility, if floating is a subnet of public use the
# router and range/netmask from public (otherwise router creation will fail)
if public_net_addr.include?(floating_net_addr)
  floating_router = public_net.router
  floating_range = "#{public_net.subnet}/#{mask_to_bits(public_net.netmask)}"
else
  floating_router = floating_net["router"]
  floating_range = "#{floating_net["subnet"]}/#{mask_to_bits(floating_net["netmask"])}"
end
floating_pool_start = floating_net_ranges[:host][:start]
floating_pool_end = floating_net_ranges[:host][:end]

ironic_net = node[:network][:networks]["ironic"]
if ironic_net
  ironic_range = "#{ironic_net["subnet"]}/#{mask_to_bits(ironic_net["netmask"])}"
  ironic_pool_start = ironic_net[:ranges][:dhcp][:start]
  ironic_pool_end = ironic_net[:ranges][:dhcp][:end]
  ironic_router = ironic_net["router"]
end

vni_start = [node[:neutron][:vxlan][:vni_start], 0].max

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

neutron_config = Barclamp::Config.load("openstack", "neutron")
ssl_insecure = CrowbarOpenStackHelper.insecure(neutron_config) || keystone_settings["insecure"]

has_ironic = ironic_net && node.roles.include?("ironic-server")

openstack_args = "--os-username '#{keystone_settings['service_user']}'"
openstack_args = "#{openstack_args} --os-password '#{keystone_settings['service_password']}'"
openstack_args = "#{openstack_args} --os-tenant-name '#{keystone_settings['service_tenant']}'"
openstack_args = "#{openstack_args} --os-auth-url '#{keystone_settings['internal_auth_url']}'"
openstack_args = "#{openstack_args} --os-region-name '#{keystone_settings['endpoint_region']}'"
if keystone_settings["api_version"] != "2.0"
  openstack_args = "#{openstack_args} --os-user-domain-name Default"
  openstack_args = "#{openstack_args} --os-project-domain-name Default"
  openstack_args = "#{openstack_args} --os-identity-api-version 3"
end
openstack_args = "#{openstack_args} --os-interface internal"
openstack_args = "#{openstack_args} --insecure" if ssl_insecure
openstack_cmd = "openstack #{openstack_args}"

fixed_network_type = ""
floating_network_type = ""

networking_plugin = node[:neutron][:networking_plugin]
ml2_type_drivers_default_provider_network = node[:neutron][:ml2_type_drivers_default_provider_network]
case networking_plugin
when "ml2"
  # For ml2 always create the floating network as a flat provider network
  # find the network node, to figure out the right "physnet" parameter
  network_node = NeutronHelper.get_network_node_from_neutron_attributes(node)
  physnet_map = NeutronHelper.get_neutron_physnets(network_node, ["nova_floating", "ironic"])
  floating_network_type = "--provider-network-type flat " \
      "--provider-physical-network #{physnet_map["nova_floating"]}"
  ironic_network_type = "--provider-network-type flat " \
      "--provider-physical-network #{physnet_map["ironic"]}"
  case ml2_type_drivers_default_provider_network
  when "vlan"
    fixed_network_type = "--provider-network-type vlan " \
        "--provider-segment #{fixed_net["vlan"]} " \
        "--provider-physical-network physnet1"
  when "gre"
    fixed_network_type = "--provider-network-type gre --provider-segment 1"
  when "vxlan"
    fixed_network_type = "--provider-network-type vxlan " \
        "--provider-segment #{vni_start}"
  else
    Chef::Log.error("default provider network ml2 type driver " \
        "'#{ml2_type_drivers_default_provider_network}' invalid for creating provider networks")
  end
when "vmware"
  fixed_network_type = ""
  # We would like to be sure that floating network will be created
  # without any additional options, NSX will take care about everything.
  floating_network_type = ""
else
  Chef::Log.error("networking plugin '#{networking_plugin}' invalid for creating provider networks")
end

execute "create_fixed_network" do
  command "#{openstack_cmd} network create --share #{fixed_network_type} fixed"
  not_if "out=$(#{openstack_cmd} network list); [ $? != 0 ] || echo ${out} | grep -q ' fixed '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_floating_network" do
  command "#{openstack_cmd} network create --external #{floating_network_type} floating"
  not_if "out=$(#{openstack_cmd} network list); [ $? != 0 ] || echo ${out} | grep -q ' floating '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_ironic_network" do
  command "#{openstack_cmd} network create --share #{ironic_network_type} ironic"
  only_if { has_ironic }
  not_if "out=$(#{openstack_cmd} network list); [ $? != 0 ] || echo ${out} | grep -q ' ironic '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_fixed_subnet" do
  command "#{openstack_cmd} subnet create --network fixed " \
      "--allocation-pool start=#{fixed_pool_start},end=#{fixed_pool_end} " \
      "--subnet-range #{fixed_range} fixed"
  not_if "out=$(#{openstack_cmd} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' fixed '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_floating_subnet" do
  command "#{openstack_cmd} subnet create --network floating " \
      "--allocation-pool start=#{floating_pool_start},end=#{floating_pool_end} " \
      "--gateway #{floating_router} --subnet-range #{floating_range} --no-dhcp floating"
  not_if "out=$(#{openstack_cmd} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' floating '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_ironic_subnet" do
  command "#{openstack_cmd} subnet create --network ironic --ip-version=4 " \
      "--allocation-pool start=#{ironic_pool_start},end=#{ironic_pool_end} " \
      "--gateway #{ironic_router} --subnet-range #{ironic_range} --dhcp ironic"
  only_if { has_ironic }
  not_if "out=$(#{openstack_cmd} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' ironic '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_router" do
  command "#{openstack_cmd} router create router-floating"
  not_if "out=$(#{openstack_cmd} router list); [ $? != 0 ] || echo ${out} | grep -q router-floating"
  retries 5
  retry_delay 10
  action :nothing
end

execute "set_router_gateway" do
  command "#{openstack_cmd} router set --external-gateway floating router-floating"
  # on Newton, the output for external_gateway_info was an empty string, on Ocata, the output is None
  not_if "out=$(#{openstack_cmd} router show router-floating -f shell) ; " \
      "[ $? != 0 ] || eval $out && [ \"${external_gateway_info}\" != \"None\" ] && " \
      "[ \"${external_gateway_info}\" != \"\" ]"
  retries 5
  retry_delay 10
  action :nothing
end

execute "add_fixed_network_to_router" do
  command "#{openstack_cmd} router add subnet router-floating fixed"
  not_if "out=$(#{openstack_cmd} port list --router router-floating --network fixed | wc -l); " \
      "[ $? != 0 ] || (( ${out} > 1 ))"
  retries 5
  retry_delay 10
  action :nothing
end

execute "add_ironic_network_to_router" do
  command "#{openstack_cmd} router add subnet router-floating ironic"
  only_if { has_ironic }
  not_if "out=$(#{openstack_cmd} port list --router router-floating --network ironic | wc -l); " \
      "[ $? != 0 ] || (( ${out} > 1 ))"
  retries 5
  retry_delay 10
  action :nothing
end

execute "Neutron network configuration" do
  command "#{openstack_cmd} network list &>/dev/null"
  retries 5
  retry_delay 10
  action :nothing
  notifies :run, "execute[create_fixed_network]", :delayed
  notifies :run, "execute[create_floating_network]", :delayed
  notifies :run, "execute[create_ironic_network]", :delayed
  notifies :run, "execute[create_fixed_subnet]", :delayed
  notifies :run, "execute[create_floating_subnet]", :delayed
  notifies :run, "execute[create_ironic_subnet]", :delayed
  notifies :run, "execute[create_router]", :delayed
  notifies :run, "execute[set_router_gateway]", :delayed
  notifies :run, "execute[add_fixed_network_to_router]", :delayed
  notifies :run, "execute[add_ironic_network_to_router]", :delayed
end

# This is to trigger all the above "execute" resources to run :delayed, so that
# they run at the end of the chef-client run, after the neutron service has been
# restarted (in case of a config change)
execute "Trigger Neutron network configuration" do
  command "true"
  notifies :run, "execute[Neutron network configuration]", :delayed
end

