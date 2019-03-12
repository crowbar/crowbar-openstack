neutron = node_search_with_cache("roles:neutron-server").first
keystone_settings = KeystoneHelper.keystone_settings(neutron, "neutron")
# HACK keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)


env = "OS_USERNAME='#{keystone_settings["service_user"]}' "
env << "OS_PASSWORD='#{keystone_settings["service_password"]}' "
env << "OS_PROJECT_NAME='#{keystone_settings["service_tenant"]}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_REGION_NAME='#{keystone_settings["endpoint_region"]}' "
env << "OS_INTERFACE=internal "
env << "OS_USER_DOMAIN_NAME=Default "
env << "OS_PROJECT_DOMAIN_NAME=Default "
env << "OS_IDENTITY_API_VERSION=3"
openstack = "#{env} openstack"


def mask_to_bits(mask)
  IPAddr.new(mask).to_i.to_s(2).count("1")
end

##{ssl_insecure ? "--insecure" : ""}

# neutron = node_search_with_cache("roles:neutron-server").first
# net = Barclamp::Inventory.get_network_definition(neutron,  "lb-mgmt-net")
# Chef::Log.info "YYY... #{net.to_json}"
#
# net_ranges = net["ranges"]
# net_range = "#{net["subnet"]}/#{mask_to_bits(net["netmask"])}"
# net_pool_start = net_ranges[:host][:start]
# net_pool_end = net_ranges[:host][:end]
#
# networking_plugin = node[:neutron][:networking_plugin]
# ml2_type_drivers_default_provider_network = node[:neutron][:ml2_type_drivers_default_provider_network]
# case networking_plugin
# when "ml2"
#   # For ml2 always create the floating network as a flat provider network
#   # find the network node, to figure out the right "physnet" parameter
#   network_node = NeutronHelper.get_network_node_from_neutron_attributes(node)
#   physnet_map = NeutronHelper.get_neutron_physnets(network_node, ["nova_floating", "ironic"])
#   network_type = "--provider-network-type flat " \
#       "--provider-physical-network #{physnet_map["ironic"]}"
#   case ml2_type_drivers_default_provider_network
#   when "vlan"
#     network_type = "--provider-network-type vlan " \
#         "--provider-segment #{net["vlan"]} " \
#         "--provider-physical-network physnet1"
#   when "gre"
#     network_type = "--provider-network-type gre --provider-segment 1"
#   when "vxlan"
#     vni_start = [node[:neutron][:vxlan][:vni_start], 0].max
#     network_type = "--provider-network-type vxlan " \
#         "--provider-segment #{vni_start}"
#   else
#     Chef::Log.error("default provider network ml2 type driver " \
#         "'#{ml2_type_drivers_default_provider_network}' invalid for creating provider networks")
#   end
# when "vmware"
#   network_type = ""
#   # We would like to be sure that floating network will be created
#   # without any additional options, NSX will take care about everything.
#   network_type = ""
# else
#   Chef::Log.error("networking plugin '#{networking_plugin}' invalid for creating provider networks")
# end
#
#

net_name = node[:octavia][:amphora][:manage_net]
project = "--project #{node[:octavia][:amphora][:project]}"
network_type = ""  #HACK
net_pool_start = "192.168.126.10"#HACK
net_pool_end = "192.168.126.230"#HACK
net_range = "192.168.126.0/#{mask_to_bits('255.255.255.0')}"#HACK

#TODO Is it necessary? --share
execute "create_octavia_network" do
  command "#{openstack} network create  #{network_type} #{project}  #{net_name}"
  not_if "out=$(#{openstack} network list); [ $? != 0 ] || echo ${out} | grep -q '#{net_name}'"
  retries 5
  retry_delay 10
  action :run
end

execute "create_octavia_subnet" do
  command "#{openstack} subnet create --network  \"#{net_name}\" " \
      "--allocation-pool start=#{net_pool_start},end=#{net_pool_end} " \
      "--subnet-range #{net_range} #{net_name}"
  not_if "out=$(#{openstack} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' #{net_name} '"
  retries 5
  retry_delay 10
  action :run
end
