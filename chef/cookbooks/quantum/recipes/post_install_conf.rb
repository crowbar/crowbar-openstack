# Copyright 2011 Dell, Inc.
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
require 'ipaddr'

def mask_to_bits(mask)
  IPAddr.new(mask).to_i.to_s(2).count("1")
end

fixed_net = node[:network][:networks]["nova_fixed"]
fixed_range = "#{fixed_net["subnet"]}/#{mask_to_bits(fixed_net["netmask"])}"
fixed_router_pool_start = fixed_net[:ranges][:router][:start]
fixed_router_pool_end = fixed_net[:ranges][:router][:end]
fixed_pool_start = fixed_net[:ranges][:dhcp][:start]
fixed_pool_end = fixed_net[:ranges][:dhcp][:end]
fixed_first_ip = IPAddr.new("#{fixed_range}").to_range().to_a[2]
fixed_last_ip = IPAddr.new("#{fixed_range}").to_range().to_a[-2]

fixed_pool_start = fixed_first_ip if fixed_first_ip > fixed_pool_start
fixed_pool_end = fixed_last_ip if fixed_last_ip < fixed_pool_end 


#this code seems to be broken in case complicated network when floating network outside of public network
public_net = node[:network][:networks]["public"]
public_range = "#{public_net["subnet"]}/#{mask_to_bits(public_net["netmask"])}"
public_router = "#{public_net["router"]}"
public_vlan = public_net["vlan"]
floating_net = node[:network][:networks]["nova_floating"]
floating_range = "#{floating_net["subnet"]}/#{mask_to_bits(floating_net["netmask"])}"
floating_pool_start = floating_net[:ranges][:host][:start]
floating_pool_end = floating_net[:ranges][:host][:end]

floating_first_ip = IPAddr.new("#{public_range}").to_range().to_a[2]
floating_last_ip = IPAddr.new("#{public_range}").to_range().to_a[-2]
floating_pool_start = floating_first_ip if floating_first_ip > floating_pool_start

floating_pool_end = floating_last_ip if floating_last_ip < floating_pool_end

env_filter = " AND keystone_config_environment:keystone-config-#{node[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_service_port = keystone["keystone"]["api"]["service_port"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
Chef::Log.info("Keystone server found at #{keystone_address}")


ENV['OS_USERNAME'] = admin_username
ENV['OS_PASSWORD'] = admin_password
ENV['OS_TENANT_NAME'] = "admin"
ENV['OS_AUTH_URL'] = "http://#{keystone_address}:#{keystone_service_port}/v2.0/"


if node[:quantum][:networking_mode] == 'vlan'
  fixed_network_type = "--provider:network_type vlan --provider:segmentation_id #{fixed_net["vlan"]} --provider:physical_network physnet1"
elsif node[:quantum][:networking_mode] == 'gre'
  fixed_network_type = "--provider:network_type gre --provider:segmentation_id 1"
else
  fixed_network_type = "--provider:network_type flat --provider:physical_network physnet1"
end

execute "create_fixed_network" do
  command "quantum net-create fixed --shared #{fixed_network_type}"
  not_if "quantum net-list | grep -q ' fixed '"
end

execute "create_floating_network" do
  command "quantum net-create floating --router:external=True"
  not_if "quantum net-list | grep -q ' floating '"
end

execute "create_fixed_subnet" do
  command "quantum subnet-create --name fixed --allocation-pool start=#{fixed_pool_start},end=#{fixed_pool_end} --gateway #{fixed_router_pool_end} fixed #{fixed_range}"
  not_if "quantum subnet-list | grep -q ' fixed '"
end
execute "create_floating_subnet" do
  command "quantum subnet-create --name floating --allocation-pool start=#{floating_pool_start},end=#{floating_pool_end} --gateway #{public_router} floating #{public_range} --enable_dhcp False"
  not_if "quantum subnet-list | grep -q ' floating '"
end

execute "create_router" do
  command "quantum router-create router-floating ; quantum router-gateway-set router-floating floating ; quantum router-interface-add router-floating fixed"
  not_if "quantum router-list | grep -q router-floating"
end


def networks_params_equal?(netw1, netw2, keys_list)
  h1 = keys_list.collect{ |key| netw1[key] }
  h2 = keys_list.collect{ |key| netw2[key] }
  h1 == h2
end

####networking part


fip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "nova_fixed")
if fip
#  fixed_address = fip.address
#  fixed_mask = fip.netmask
  fixed_interface = fip.interface
  fixed_interface = "#{fip.interface}.#{fip.vlan}" if fip.use_vlan
else
  fixed_interface = nil
end
#we have to rely on public net since we consciously decided not to allocate floating network
keys_list = %w{conduit vlan use_vlan add_bridge}
netw1 = node[:network][:networks][:nova_floating]
netw2 = node[:network][:networks][:public]
if networks_params_equal? netw1, netw2, keys_list
  pip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public")
else
  pip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "nova_floating")
end
if pip
#  public_address = pip.address
#  public_mask = pip.netmask
  public_interface = pip.interface
  public_interface = "#{pip.interface}.#{pip.vlan}" if pip.use_vlan
else
  public_interface = nil
end

flat_network_bridge = fixed_net["use_vlan"] ? "br#{fixed_net["vlan"]}" : "br#{fixed_interface}"

execute "create_int_br" do
  command "ovs-vsctl add-br br-int"
  not_if "ovs-vsctl list-br | grep -q br-int"
end

execute "create_fixed_br" do
  command "ovs-vsctl add-br br-fixed"
  not_if "ovs-vsctl list-br | grep -q br-fixed"
end

execute "create_public_br" do
  command "ovs-vsctl add-br br-public"
  not_if "ovs-vsctl list-br | grep -q br-public"
end

execute "add_fixed_port_#{flat_network_bridge}" do
  command "ovs-vsctl del-port br-fixed #{flat_network_bridge} ; ovs-vsctl add-port br-fixed #{flat_network_bridge}"
  not_if "ovs-dpctl show system@br-fixed | grep -q #{flat_network_bridge}"
end

execute "add_public_port_#{public_interface}" do
  command "ovs-vsctl del-port br-public #{public_interface} ; ovs-vsctl add-port br-public #{public_interface}"
  not_if "ovs-dpctl show system@br-public | grep -q #{public_interface}"
end

#this workaround for metadata service, should be removed when quantum-metadata-proxy will be released
#it parses jsoned csv output of quantum to get address of router to pass it into metadata node
ruby_block "get_fixed_net_router" do
  block do
    require 'csv'
    require 'json'
    csv_data = `quantum router-port-list -F fixed_ips -f csv router-floating -- --device_owner network:router_gateway`
    node.set[:quantum][:network][:fixed_router] = JSON.parse(CSV.parse(csv_data)[1].join)["ip_address"]
    node.save
  end
  only_if { node[:quantum][:network][:fixed_router] == "127.0.0.1" }
end

if node[:quantum][:networking_mode] != 'local'
  per_tenant_vlan=true
else
  per_tenant_vlan=false
end

if per_tenant_vlan
#we should add foating router into user's private networks and pass that network to novas to get metadata service working properly
  ruby_block "get_private_networks" do
    block do
      require 'csv'
      csv_data = `quantum subnet-list -c cidr -f csv -- --shared false --enable_dhcp true`
      private_quantum_networks = CSV.parse(csv_data)
      private_quantum_networks.shift
      node.set[:quantum][:network][:private_networks] = private_quantum_networks
      node.save
    end
  end

  ruby_block "add_floating_router_to_private_networks" do
    block do
      require 'csv'
      csv_data = `quantum subnet-list -c id -f csv -- --shared false --enable_dhcp true`
      private_quantum_ids = CSV.parse(csv_data)
      private_quantum_ids.shift
      private_quantum_ids.each do |subnet_id|
        system("quantum router-interface-add router-floating #{subnet_id}")
      end
    end
  end
end

#execute "move_fixed_ip" do
#  command "ip address flush dev #{fixed_interface} ; ip address flush dev #{flat_network_bridge} ; ifconfig br-fixed #{fixed_address} netmask #{fixed_mask}"
#  not_if "ip addr show br-fixed | grep -q #{fixed_address}"
#end

#i dunno how to deal with this in proper way
#currently if public and floating net share the same l2 crowbar bring up single physical iface for this diffent entyties, so we have to deal somehow with this behavior
if networks_params_equal? netw1, netw2, keys_list
  public_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
  public_mask = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").netmask
  execute "move_public_ip_#{public_address}_from_#{public_interface}_to_br-public" do
    command "ip addr flush dev #{public_interface} ; ifconfig br-public #{public_address} netmask #{public_mask}"
    not_if "ip addr show br-public | grep -q #{public_address}"
  end
end
