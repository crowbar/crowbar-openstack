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

keystone_settings = NeutronHelper.keystone_settings(node)

neutron_insecure = node[:neutron][:api][:protocol] == 'https' && node[:neutron][:ssl][:insecure]
ssl_insecure = keystone_settings['insecure'] || neutron_insecure

neutron_args = "--os-username #{keystone_settings['service_user']}"
neutron_args = "#{neutron_args} --os-password #{keystone_settings['service_password']}"
neutron_args = "#{neutron_args} --os-tenant-name #{keystone_settings['service_tenant']}"
neutron_args = "#{neutron_args} --os-auth-url #{keystone_settings['internal_auth_url']}"
if node[:platform] == "suse" or node[:neutron][:use_gitrepo]
  # these options are backported in SUSE packages, but not in Ubuntu
  neutron_args = "#{neutron_args} --endpoint-type internalURL"
  neutron_args = "#{neutron_args} --insecure" if ssl_insecure
end
neutron_cmd = "neutron #{neutron_args}"

case node[:neutron][:networking_plugin]
when "openvswitch"
  floating_network_type = ""
  if node[:neutron][:networking_mode] == 'vlan'
    fixed_network_type = "--provider:network_type vlan --provider:segmentation_id #{fixed_net["vlan"]} --provider:physical_network physnet1"
  elsif node[:neutron][:networking_mode] == 'gre'
    fixed_network_type = "--provider:network_type gre --provider:segmentation_id 1"
    floating_network_type = "--provider:network_type gre --provider:segmentation_id 2"
  else
    fixed_network_type = "--provider:network_type flat --provider:physical_network physnet1"
  end
when "linuxbridge"
    fixed_network_type = "--provider:network_type vlan --provider:segmentation_id #{fixed_net["vlan"]} --provider:physical_network physnet1"
    floating_network_type = "--provider:network_type vlan --provider:segmentation_id #{public_net["vlan"]} --provider:physical_network physnet1"
end


# This is some bad hack: we need to restart the server now if there was a
# configuration change. We cannot use :immediately to directly restart the
# service earlier, because it would be started before all configuration
# files get written.
services_to_restart = []
services_started = []

unless node[:neutron][:use_gitrepo]
  case node[:neutron][:networking_plugin]
  when "openvswitch", "cisco"
    agent_config_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
  when "linuxbridge"
    agent_config_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
  when "vmware"
    agent_config_path = "/etc/neutron/plugins/nicira/nvp.ini"
  end
  neutron_service_name = node[:neutron][:platform][:service_name]
else
  case node[:neutron][:networking_plugin]
  when "openvswitch"
    agent_config_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
  when "linuxbridge"
    agent_config_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
  when "vmware"
    agent_config_path = "/etc/neutron/plugins/nicira/nvp.ini"
  end
  neutron_service_name = "neutron-server"
end
if node[:neutron][:use_ml2] && node[:neutron][:networking_plugin] != "vmware"
  plugin_cfg_path = "/etc/neutron/plugins/ml2/ml2_conf.ini"
else
  plugin_cfg_path = agent_config_path
end

ruby_block "mark neutron-server as restart for post-install" do
  block do
    services_to_restart << neutron_service_name
  end
  action :nothing
  subscribes :create, resources("template[/etc/neutron/api-paste.ini]"), :immediately
  subscribes :create, resources("template[#{plugin_cfg_path}]"), :immediately
  subscribes :create, resources("template[/etc/neutron/neutron.conf]"), :immediately
end

ruby_block "mark neutron-server as started" do
  block do
    services_started << neutron_service_name
  end
  action :nothing
  subscribes :create, resources("service[#{neutron_service_name}]"), :immediately
end

ruby_block "restart services for post-install" do
  block do
    services_to_restart.uniq.each do |service|
      unless services_started.include? service
        Chef::Log.info("Restarting #{service}")
        %x{/etc/init.d/#{service} restart}
      end
    end
  end
end


execute "create_fixed_network" do
  command "#{neutron_cmd} net-create fixed --shared #{fixed_network_type}"
  not_if "out=$(#{neutron_cmd} net-list); [ $? != 0 ] || echo ${out} | grep -q ' fixed '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_floating_network" do
  command "#{neutron_cmd} net-create floating --router:external=True #{floating_network_type}"
  not_if "out=$(#{neutron_cmd} net-list); [ $? != 0 ] || echo ${out} | grep -q ' floating '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_fixed_subnet" do
  command "#{neutron_cmd} subnet-create --name fixed --allocation-pool start=#{fixed_pool_start},end=#{fixed_pool_end} --gateway #{fixed_router_pool_end} fixed #{fixed_range}"
  not_if "out=$(#{neutron_cmd} subnet-list); [ $? != 0 ] || echo ${out} | grep -q ' fixed '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_floating_subnet" do
  command "#{neutron_cmd} subnet-create --name floating --allocation-pool start=#{floating_pool_start},end=#{floating_pool_end} --gateway #{public_router} floating #{public_range} --enable_dhcp False"
  not_if "out=$(#{neutron_cmd} subnet-list); [ $? != 0 ] || echo ${out} | grep -q ' floating '"
  retries 5
  retry_delay 10
  action :nothing
end

execute "create_router" do
  command "#{neutron_cmd} router-create router-floating"
  not_if "out=$(#{neutron_cmd} router-list); [ $? != 0 ] || echo ${out} | grep -q router-floating"
  retries 5
  retry_delay 10
  action :nothing
end

execute "set_router_gateway" do
  command "#{neutron_cmd} router-gateway-set router-floating floating"
  not_if "out=$(#{neutron_cmd} router-show router-floating -f shell) ; [ $? != 0 ] || eval $out && [ \"${external_gateway_info}\" != \"\" ]"
  retries 5
  retry_delay 10
  action :nothing
end

execute "add_fixed_network_to_router" do
  command "#{neutron_cmd} router-interface-add router-floating fixed"
  not_if "out1=$(#{neutron_cmd} subnet-show -f shell fixed) ; rc1=$?; eval $out1 ; out2=$(#{neutron_cmd} router-port-list router-floating); [ $? != 0 ] || [ $rc1 != 0 ] || echo $out2 | grep -q $id"
  retries 5
  retry_delay 10
  action :nothing
end

execute "Neutron network configuration" do
  command "#{neutron_cmd} net-list &>/dev/null"
  retries 5
  retry_delay 10
  notifies :run, "execute[create_fixed_network]", :immediately
  notifies :run, "execute[create_floating_network]", :immediately
  notifies :run, "execute[create_fixed_subnet]", :immediately
  notifies :run, "execute[create_floating_subnet]", :immediately
  notifies :run, "execute[create_router]", :immediately
  notifies :run, "execute[set_router_gateway]", :immediately
  notifies :run, "execute[add_fixed_network_to_router]", :immediately
end

