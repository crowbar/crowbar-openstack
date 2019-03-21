require "ipaddr"

def mask_to_bits(mask)
  IPAddr.new(mask).to_i.to_s(2).count("1")
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

env = "OS_USERNAME='#{keystone_settings["service_user"]}' "
env << "OS_PASSWORD='#{keystone_settings["service_password"]}' "
env << "OS_PROJECT_NAME='#{keystone_settings["service_tenant"]}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_REGION_NAME='#{keystone_settings["endpoint_region"]}' "
env << "OS_INTERFACE=internal "
env << "OS_USER_DOMAIN_NAME=Default "
env << "OS_PROJECT_DOMAIN_NAME=Default "
env << "OS_IDENTITY_API_VERSION=3"

ssl_insecure = true #TODO: add entry to default and templates (check neutorn)

cmd = "#{env} openstack #{ssl_insecure ? "--insecure" : ""}"

net_name = node[:octavia][:amphora][:manage_net]
octavia_net = node[:network][:networks][net_name]
router_name = "lb-router"
octavia_nete_type = "--provider-network-type vlan "

if octavia_net
  octavia_range = "#{octavia_net["subnet"]}/#{mask_to_bits(octavia_net["netmask"])}"
  octavia_pool_start = octavia_net[:ranges][:host][:start]
  octavia_pool_end = octavia_net[:ranges][:host][:end]
end

execute "create_octavia_network" do
  command "#{cmd} network create --share #{octavia_nete_type} #{net_name}"
  only_if { octavia_net }
  not_if "out=$(#{cmd} network list); [ $? != 0 ] || echo ${out} | grep -q ' #{net_name} '"
  retries 5
  retry_delay 10
  action :run
end

execute "create_octavia_subnet" do
  command "#{cmd} subnet create --network #{net_name} --ip-version=4 " \
      "--allocation-pool start=#{octavia_pool_start},end=#{octavia_pool_end} " \
      "--subnet-range #{octavia_range} --dhcp #{net_name}"
  only_if { octavia_net }
  not_if "out=$(#{cmd} subnet list); [ $? != 0 ] || echo ${out} | grep -q ' #{net_name} '"
  retries 5
  retry_delay 10
  action :run
end

execute "create_octavia_router" do
  command "#{cmd} router create #{router_name}"
  only_if { octavia_net }
  not_if "out=$(#{cmd} router list); [ $? != 0 ] || echo ${out} | grep -q ' #{router_name} '"
  retries 5
  retry_delay 10
  action :run
end

execute "add_octavia_subnet_to_router" do
  command "#{cmd} router add subnet #{router_name} #{net_name}"
  only_if { octavia_net }
  not_if "out=$(#{cmd} router show #{router_name}); [ $? != 0 ] || echo ${out} | grep -q " \
    "$(#{cmd} subnet show #{net_name} | tr -d ' ' | grep '|id|' | cut -d '|' -f 3)"
  retries 5
  retry_delay 10
  action :run
end

execute "set_octavia_set_external_gateway" do
  command "#{cmd} router set --external-gateway floating #{router_name}"
  only_if { octavia_net }
  retries 5
  retry_delay 10
  action :run
end

#TODO: Sync

ruby_block 'add_octavia_network_route' do
  block do
    filter = '| tr ":" "\n" | grep -A 1 ip_address | tail -n 1 | tr -d "\"|}|]|\\\\" | tr -d " "'
    gateway_id = shell_out("#{cmd} router show #{router_name} -c external_gateway_info " \
        " -f json #{filter}").stdout

    shell_out("ip r add #{octavia_range} via #{gateway_id}")
  end
  action :nothing
  subscribes :create, "execute[set_octavia_set_external_gateway]", :immediately
end
