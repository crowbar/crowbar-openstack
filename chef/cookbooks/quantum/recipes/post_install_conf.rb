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

keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_host = keystone[:fqdn]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_insecure = keystone_protocol == 'https' && keystone[:keystone][:ssl][:insecure]

admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
admin_tenant = keystone["keystone"]["admin"]["tenant"] rescue "admin"
Chef::Log.info("Keystone server found at #{keystone_host}")

quantum_insecure = node[:quantum][:api][:protocol] == 'https' && node[:quantum][:ssl][:insecure]
ssl_insecure = keystone_insecure || quantum_insecure

quantum_args = "--os-username #{node[:quantum][:service_user]}"
quantum_args = "#{quantum_args} --os-password #{node[:quantum][:service_password]}"
quantum_args = "#{quantum_args} --os-tenant-name #{keystone[:keystone][:service][:tenant]}"
quantum_args = "#{quantum_args} --os-auth-url #{keystone_protocol}://#{keystone_host}:#{keystone_service_port}/v2.0/"
if node[:platform] == "suse" or node[:quantum][:use_gitrepo]
  # these options are backported in SUSE packages, but not in Ubuntu
  quantum_args = "#{quantum_args} --endpoint-type internalURL"
  quantum_args = "#{quantum_args} --insecure" if ssl_insecure
end
quantum_cmd = "quantum #{quantum_args}"

case node[:quantum][:networking_plugin]
when "openvswitch"
  floating_network_type = ""
  if node[:quantum][:networking_mode] == 'vlan'
    fixed_network_type = "--provider:network_type vlan --provider:segmentation_id #{fixed_net["vlan"]} --provider:physical_network physnet1"
  elsif node[:quantum][:networking_mode] == 'gre'
    fixed_network_type = "--provider:network_type gre --provider:segmentation_id 1"
    floating_network_type = "--provider:network_type gre --provider:segmentation_id 2"
  else
    fixed_network_type = "--provider:network_type flat --provider:physical_network physnet1"
  end
when "linuxbridge"
    fixed_network_type = "--provider:network_type vlan --provider:segmentation_id #{fixed_net["vlan"]} --provider:physical_network physnet1"
    floating_network_type = "--provider:network_type vlan --provider:segmentation_id #{public_net["vlan"]} --provider:physical_network physnet1"
end

execute "create_fixed_network" do
  command "#{quantum_cmd} net-create fixed --shared #{fixed_network_type}"
  not_if "#{quantum_cmd} net-list | grep -q ' fixed '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_floating_network" do
  command "#{quantum_cmd} net-create floating --router:external=True #{floating_network_type}"
  not_if "#{quantum_cmd} net-list | grep -q ' floating '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_fixed_subnet" do
  command "#{quantum_cmd} subnet-create --name fixed --allocation-pool start=#{fixed_pool_start},end=#{fixed_pool_end} --gateway #{fixed_router_pool_end} fixed #{fixed_range}"
  not_if "#{quantum_cmd} subnet-list | grep -q ' fixed '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_floating_subnet" do
  command "#{quantum_cmd} subnet-create --name floating --allocation-pool start=#{floating_pool_start},end=#{floating_pool_end} --gateway #{public_router} floating #{public_range} --enable_dhcp False"
  not_if "#{quantum_cmd} subnet-list | grep -q ' floating '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_router" do
  command "#{quantum_cmd} router-create router-floating ; #{quantum_cmd} router-gateway-set router-floating floating ; #{quantum_cmd} router-interface-add router-floating fixed"
  not_if "#{quantum_cmd} router-list | grep -q router-floating"
  retries 5
  retry_delay 10
  action :nothing
end

execute "Quantum network configuration" do
  command "#{quantum_cmd} net-list"
  retries 5
  retry_delay 10
  notifies :run, "execute[create_floating_network]", :immediately
  notifies :run, "execute[create_fixed_subnet]", :immediately
  notifies :run, "execute[create_floating_subnet]", :immediately
  notifies :run, "execute[create_router]", :immediately
end.run_action(:run)

def networks_params_equal?(netw1, netw2, keys_list)
  h1 = keys_list.collect{ |key| netw1[key] }
  h2 = keys_list.collect{ |key| netw2[key] }
  h1 == h2
end

#this workaround for metadata service, should be removed when quantum-metadata-proxy will be released
#it parses jsoned csv output of quantum to get address of router to pass it into metadata node
ruby_block "get_fixed_net_router" do
  block do
    require 'csv'
    require 'json'
    csv_data = `#{quantum_cmd} router-port-list -f csv router-floating -- --device_owner network:router_gateway`
    Chef::Log.info(csv_data)
    node.set[:quantum][:network][:fixed_router] = JSON.parse(CSV.parse(csv_data)[1][-1])["ip_address"]
    node.save
  end
  only_if { node[:quantum][:network][:fixed_router] == "127.0.0.1" }
end

if node[:quantum][:networking_mode] != "local"
  ruby_block "get_private_networks" do
    block do
      require 'csv'
      csv_data = `#{quantum_cmd} subnet-list -c cidr -f csv -- --shared false --enable_dhcp true`
      private_quantum_networks = CSV.parse(csv_data)
      private_quantum_networks.shift
      node.set[:quantum][:network][:private_networks] = private_quantum_networks
      node.save
    end
  end

  ruby_block "add_floating_router_to_private_networks" do
    block do
      require 'csv'
      csv_data = `#{quantum_cmd} subnet-list -c id -f csv -- --shared false --enable_dhcp true`
      private_quantum_ids = CSV.parse(csv_data)
      private_quantum_ids.shift
      private_quantum_ids.each do |subnet_id|
        system("#{quantum_cmd} router-interface-add router-floating #{subnet_id}")
      end
    end
  end
end

if node[:quantum][:networking_plugin] == "linuxbridge"
  bound_if = (node[:crowbar_wall][:network][:nets][:public].last rescue nil)
  quantum_bridge "floating bridge" do
    network_name "floating"
    slaves [bound_if]
    type "linuxbridge"
    quantum_cmd quantum_cmd

    action :create
  end
end
