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

unless node[:quantum][:use_gitrepo]
  package "quantum" do
    action :install
  end
else
  pfs_and_install_deps(@cookbook_name)
  link_service @cookbook_name do
    bin_name "quantum-server --config-dir /etc/quantum/"
  end
  create_user_and_dirs(@cookbook_name)
  execute "quantum_cp_policy.json" do
    command "cp /opt/quantum/etc/policy.json /etc/quantum/"
    creates "/etc/quantum/policy.json"
  end
  execute "quantum_cp_rootwrap" do
    command "cp -r /opt/quantum/etc/quantum/rootwrap.d /etc/quantum/rootwrap.d"
    creates "/etc/quantum/rootwrap.d"
  end
  cookbook_file "/etc/quantum/rootwrap.conf" do
    source "quantum-rootwrap.conf"
    mode 00644
    owner "quantum"
  end
end

template "/etc/sudoers.d/quantum-rootwrap" do
  source "quantum-rootwrap.erb"
  mode 0440
  variables(:user => "quantum")
end




service "quantum" do
  supports :status => true, :restart => true
  action :enable
end

if node[:quantum][:use_gitrepo]
  link_service "quantum-openvswitch-agent" do
    bin_name "quantum-openvswitch-agent --config-dir /etc/quantum/"
  end
  link_service "quantum-dhcp-agent" do
    bin_name "quantum-dhcp-agent --config-dir /etc/quantum/"
  end
  link_service "quantum-l3-agent" do
    bin_name "quantum-l3-agent --config-dir /etc/quantum/"
  end
end

kern_release=`uname -r`
package "linux-headers-#{kern_release}" do
    action :install
end
package "openvswitch-switch" do
    action :install
end
package "openvswitch-datapath-dkms" do
    action :install
end



service "openvswitch-switch" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end
service "quantum-openvswitch-agent" do
  supports :status => true, :restart => true
  action :enable
end
service "quantum-dhcp-agent" do
  supports :status => true, :restart => true
  action :enable
end
service "quantum-l3-agent" do
  supports :status => true, :restart => true
  action :enable
end


::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['quantum']['db']['password'] = secure_password
node.set_unless['quantum']['db']['ovs_password'] = secure_password

if node[:quantum][:sql_engine] == "mysql"
    Chef::Log.info("Configuring Quantum to use MySQL backend")

    include_recipe "mysql::client"

    package "python-mysqldb" do
        action :install
    end

    env_filter = " AND mysql_config_environment:mysql-config-#{node[:quantum][:mysql_instance]}"
    mysqls = search(:node, "roles:mysql-server#{env_filter}") || []
    if mysqls.length > 0
        mysql = mysqls[0]
        mysql = node if mysql.name == node.name
    else
        mysql = node
    end

    mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
    Chef::Log.info("Mysql server found at #{mysql_address}")
    
    # Create the Quantum Database
    mysql_database "create #{node[:quantum][:db][:database]} database" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:quantum][:db][:database]
        action :create_db
    end

    mysql_database "create dashboard database user" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:quantum][:db][:database]
        action :query
        sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{node[:quantum][:db][:database]}.* to '#{node[:quantum][:db][:user]}'@'%' IDENTIFIED BY '#{node[:quantum][:db][:password]}';"
    end

    # Create the Quantum Database
    mysql_database "create #{node[:quantum][:db][:database]} database" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:quantum][:db][:ovs_database]
        action :create_db
    end

    mysql_database "create dashboard database user" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:quantum][:db][:ovs_database]
        action :query
        sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{node[:quantum][:db][:ovs_database]}.* to '#{node[:quantum][:db][:ovs_user]}'@'%' IDENTIFIED BY '#{node[:quantum][:db][:ovs_password]}';"
    end


    ovs_sql_connection = "mysql://#{node[:quantum][:db][:ovs_user]}:#{node[:quantum][:db][:ovs_password]}@#{mysql_address}/#{node[:quantum][:db][:ovs_database]}"
    sql_connection = "mysql://#{node[:quantum][:db][:user]}:#{node[:quantum][:db][:password]}@#{mysql_address}/#{node[:quantum][:db][:database]}"




elsif node[:quantum][:sql_engine] == "sqlite"
    Chef::Log.info("Configuring Quantum to use SQLite backend")
    sql_connection = "sqlite:////var/lib/quantum/quantum.db"
    file "/var/lib/quantum/quantum.db" do
        owner "quantum"
        action :create_if_missing
    end
end


#env_filter = " AND nova_config_environment:nova-config-#{node[:tempest][:nova_instance]}"
#assuming we have only one nova
#TODO: nova should depend on quantum, but quantum depend on nova a bit, so we have to do somthing with this

novas = search(:node, "roles:nova-multi-controller") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end
metadata_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(nova, "public").address rescue nil
metadata_port = "8775"
per_tenant_vlan=nova[:nova][:network][:tenant_vlans] rescue false

rabbits = search(:node, "recipes:nova\\:\\:rabbit") || []
if rabbits.length > 0
  rabbit = rabbits[0]
  rabbit = node if rabbit.name == node.name
else
  rabbit = node
end
rabbit_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(rabbit, "admin").address
Chef::Log.info("Rabbit server found at #{rabbit_address}")
if rabbit[:nova]
  #agordeev:
  # rabbit settings will work only after nova proposal be deployed
  # and cinder services will be restarted then
  rabbit_settings = {
    :address => rabbit_address,
    :port => rabbit[:nova][:rabbit][:port],
    :user => rabbit[:nova][:rabbit][:user],
    :password => rabbit[:nova][:rabbit][:password],
    :vhost => rabbit[:nova][:rabbit][:vhost]
  }
else
  rabbit_settings = nil
end



env_filter = " AND keystone_config_environment:keystone-config-#{node[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end


keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_token = keystone["keystone"]["service"]["token"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["quantum"]["service_user"]
keystone_service_password = node["quantum"]["service_password"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
default_tenant = keystone["keystone"]["default"]["tenant"] rescue nil
Chef::Log.info("Keystone server found at #{keystone_address}")




def mask_to_bits(mask)
  octets = mask.split(".")
  count = 0
  octets.each do |octet|
    break if octet == "0"
    c = 1 if octet == "128"
    c = 2 if octet == "192"
    c = 3 if octet == "224"
    c = 4 if octet == "240"
    c = 5 if octet == "248"
    c = 6 if octet == "252"
    c = 7 if octet == "254"
    c = 8 if octet == "255"
    count = count + c
  end

  count
end



fixed_net=node[:network][:networks]["nova_fixed"]
fixed_range="#{fixed_net["subnet"]}/#{mask_to_bits(fixed_net["netmask"])}"
fixed_router_pool_start=fixed_net[:ranges][:router][:start]
fixed_router_pool_end=fixed_net[:ranges][:router][:end]
fixed_pool_start=fixed_net[:ranges][:dhcp][:start]
fixed_pool_end=fixed_net[:ranges][:dhcp][:end]
fixed_first_ip=IPAddr.new("#{fixed_range}").to_range().to_a[2]
fixed_last_ip=IPAddr.new("#{fixed_range}").to_range().to_a[-2]
vlan_start=fixed_net["vlan"]
vlan_end=vlan_start+2000
if fixed_first_ip > fixed_pool_start
fixed_pool_start=fixed_first_ip
end
if fixed_last_ip < fixed_pool_end
fixed_pool_end=fixed_last_ip
end



template "/etc/quantum/quantum.conf" do
    source "quantum.conf.erb"
    mode "0644"
    owner "quantum"
    variables(
      :sql_connection => sql_connection,
      :sql_idle_timeout => node[:quantum][:sql][:idle_timeout],
      :sql_min_pool_size => node[:quantum][:sql][:min_pool_size],
      :sql_max_pool_size => node[:quantum][:sql][:max_pool_size],
      :sql_pool_timeout => node[:quantum][:sql][:pool_timeout],
      :debug => node[:quantum][:debug],
      :verbose => node[:quantum][:verbose],
      :admin_token => node[:quantum][:service][:token],
      :service_port => node[:quantum][:api][:service_port], # Compute port
      :service_host => node[:quantum][:api][:service_host],
      :use_syslog => node[:quantum][:use_syslog],
      :rabbit_settings => rabbit_settings,
      :keystone_ip_address => keystone_address,
      :keystone_admin_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_admin_port => keystone_admin_port,
      :metadata_address => metadata_address,
      :metadata_port => metadata_port,
      :per_tenant_vlan => per_tenant_vlan,
      :vlan_start => vlan_start,
      :vlan_end => vlan_end
    )
    notifies :restart, resources(:service => "quantum")
    notifies :restart, resources(:service => "quantum-openvswitch-agent")
    notifies :restart, resources(:service => "quantum-dhcp-agent")
    notifies :restart, resources(:service => "quantum-l3-agent")
end


template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner "quantum"
  group "root"
  mode "0640"
  variables(
    :keystone_ip_address => keystone_address,
    :keystone_admin_token => keystone_token,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
  notifies :restart, resources(:service => "quantum"), :immediately
end


directory "/etc/quantum/plugins/openvswitch/" do
   mode 00775
   owner "quantum"
   action :create
   recursive true
end

template "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini" do
  source "ovs_quantum_plugin.ini.erb"
  owner "quantum"
  group "root"
  mode "0640"
  variables(
      :ovs_sql_connection => ovs_sql_connection
  )
  notifies :restart, resources(:service => "quantum"), :immediately
end


#execute "quantum-manage db_sync" do
#  action :run
#end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

node[:quantum][:monitor] = {} if node[:quantum][:monitor].nil?
node[:quantum][:monitor][:svcs] = [] if node[:quantum][:monitor][:svcs].nil?
node[:quantum][:monitor][:svcs] <<["quantum"]
node.save


keystone_register "quantum api wakeup keystone" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  action :wakeup
end

keystone_register "register quantum user" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give quantum user access" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

keystone_register "register quantum service" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  service_name "quantum"
  service_type "network"
  service_description "Openstack Quantum Service"
  action :add_service
end

keystone_register "register quantum endpoint" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  endpoint_service "quantum"
  endpoint_region "RegionOne"
  endpoint_publicURL "http://#{pub_ipaddress}:9696/"
  endpoint_adminURL "http://#{my_ipaddress}:9696/"
  endpoint_internalURL "http://#{my_ipaddress}:9696/"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end



#this code seems to be broken in case complicated network when floating network outside of public network
public_net=node[:network][:networks]["public"]
public_range="#{public_net["subnet"]}/#{mask_to_bits(public_net["netmask"])}"
public_router="#{public_net["router"]}"
public_vlan=public_net["vlan"]
floating_net=node[:network][:networks]["nova_floating"]
floating_range="#{floating_net["subnet"]}/#{mask_to_bits(floating_net["netmask"])}"
floating_pool_start=floating_net[:ranges][:host][:start]
floating_pool_end=floating_net[:ranges][:host][:end]

floating_first_ip=IPAddr.new("#{public_range}").to_range().to_a[2]
floating_last_ip=IPAddr.new("#{public_range}").to_range().to_a[-2]
if floating_first_ip > floating_pool_start
floating_pool_start=floating_first_ip
end
if floating_last_ip < floating_pool_end
floating_pool_end=floating_last_ip
end



ENV['OS_USERNAME']=admin_username
ENV['OS_PASSWORD']=admin_password
ENV['OS_TENANT_NAME']="admin"
ENV['OS_AUTH_URL']="http://#{keystone_address}:#{keystone_service_port}/v2.0/"


if per_tenant_vlan
  fixed_network_type="vlan --provider:segmentation_id #{fixed_net["vlan"]}"
else
  fixed_network_type="flat"
end

execute "create_fixed_network" do
  command "quantum net-create fixed --shared --provider:network_type #{fixed_network_type} --provider:physical_network physnet1"
  not_if "quantum net-list | grep -q ' fixed '"
  ignore_failure true
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end
execute "create_floating_network" do
  command "quantum net-create floating --router:external=True"
  not_if "quantum net-list | grep -q ' floating '"
  ignore_failure true
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end

execute "create_fixed_subnet" do
  command "quantum subnet-create --name fixed --allocation-pool start=#{fixed_pool_start},end=#{fixed_pool_end} --gateway #{fixed_router_pool_end} fixed #{fixed_range}"
  not_if "quantum subnet-list | grep -q ' fixed '"
  ignore_failure true
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end
execute "create_floating_subnet" do
  command "quantum subnet-create --name floating --allocation-pool start=#{floating_pool_start},end=#{floating_pool_end} --gateway #{public_router} floating #{public_range} --enable_dhcp False"
  not_if "quantum subnet-list | grep -q ' floating '"
  ignore_failure true
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end

execute "create_router" do
  command "quantum router-create router-floating ; quantum router-gateway-set router-floating floating ; quantum router-interface-add router-floating fixed"
  not_if "quantum router-list | grep -q router-floating"
  ignore_failure true
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
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
if node[:network][:networks]["nova_floating"]["conduit"]==node[:network][:networks]["public"]["conduit"] and node[:network][:networks]["nova_floating"]["vlan"]==node[:network][:networks]["public"]["vlan"] and node[:network][:networks]["nova_floating"]["use_vlan"]==node[:network][:networks]["public"]["use_vlan"] and node[:network][:networks]["nova_floating"]["add_bridge"]==node[:network][:networks]["public"]["add_bridge"]
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
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end
execute "create_fixed_br" do
  command "ovs-vsctl add-br br-fixed"
  not_if "ovs-vsctl list-br | grep -q br-fixed"
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end
execute "create_public_br" do
  command "ovs-vsctl add-br br-public"
  not_if "ovs-vsctl list-br | grep -q br-public"
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end
execute "add_fixed_port_#{flat_network_bridge}" do
  command "ovs-vsctl del-port br-fixed #{flat_network_bridge} ; ovs-vsctl add-port br-fixed #{flat_network_bridge}"
  not_if "ovs-dpctl show system@br-fixed | grep -q #{flat_network_bridge}"
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end
execute "add_public_port_#{public_interface}" do
  command "ovs-vsctl del-port br-public #{public_interface} ; ovs-vsctl add-port br-public #{public_interface}"
  not_if "ovs-dpctl show system@br-public | grep -q #{public_interface}"
  notifies :restart, resources(:service => "quantum")
  notifies :restart, resources(:service => "quantum-openvswitch-agent")
  notifies :restart, resources(:service => "quantum-dhcp-agent")
  notifies :restart, resources(:service => "quantum-l3-agent")
end

#this workaround for metadata service, should be removed when quantum-metadata-proxy will be released
#it parses jsoned csv output of quantum to get address of router to pass it into metadata node
ruby_block "get_fixed_net_router" do
   block do
     require 'csv'
     require 'json'
     csv_data=`quantum router-port-list -F fixed_ips -f csv router-floating -- --device_owner network:router_gateway`
     node.set[:quantum][:network][:fixed_router]=JSON.parse(CSV.parse(csv_data)[1].join)["ip_address"]
     node.save
   end
   ignore_failure true
   only_if { node[:quantum][:network][:fixed_router]=="127.0.0.1" }
end

if per_tenant_vlan
#we should add foating router into user's private networks and pass that network to novas to get metadata service working properly
  ruby_block "get_private_networks" do
     block do
       require 'csv'
       csv_data=`quantum subnet-list -c cidr -f csv -- --shared false`
       private_quantum_networks=CSV.parse(csv_data)
       private_quantum_networks.shift
       node.set[:quantum][:network][:private_networks]=private_quantum_networks
       node.save
     end
     ignore_failure true
  end

  ruby_block "add_floating_router_to_private_networks" do
    block do
       require 'csv'
       csv_data=`quantum subnet-list -c id -f csv -- --shared false --enable_dhcp true`
       private_quantum_ids=CSV.parse(csv_data)
       private_quantum_ids.shift
       private_quantum_ids.each do |subnet_id|
         system("quantum router-interface-add router-floating #{subnet_id}")
       end
    end
    ignore_failure true
  end
end



#execute "move_fixed_ip" do
#  command "ip address flush dev #{fixed_interface} ; ip address flush dev #{flat_network_bridge} ; ifconfig br-fixed #{fixed_address} netmask #{fixed_mask}"
#  not_if "ip addr show br-fixed | grep -q #{fixed_address}"
#end

#i dunno how to deal with this in proper way
#currently if public and floating net share the same l2 crowbar bring up single physical iface for this diffent entyties, so we have to deal somehow with this behavior
if node[:network][:networks]["nova_floating"]["conduit"]==node[:network][:networks]["public"]["conduit"] and node[:network][:networks]["nova_floating"]["vlan"]==node[:network][:networks]["public"]["vlan"] and node[:network][:networks]["nova_floating"]["use_vlan"]==node[:network][:networks]["public"]["use_vlan"] and node[:network][:networks]["nova_floating"]["add_bridge"]==node[:network][:networks]["public"]["add_bridge"]
  public_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
  public_mask = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").netmask
  execute "move_public_ip_#{public_address}_from_#{public_interface}_to_br-public" do
    command "ip addr flush dev #{public_interface} ; ifconfig br-public #{public_address} netmask #{public_mask}"
    not_if "ip addr show br-public | grep -q #{public_address}"
  end
end
