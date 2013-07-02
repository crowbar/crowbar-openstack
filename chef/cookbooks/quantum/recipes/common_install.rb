# Copyright 2013 Dell, Inc.
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

quantum = nil
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  quantums = search(:node, "roles:quantum-server AND roles:quantum-config-#{node[:nova][:quantum_instance]}")
  quantum = quantums.first || raise("Quantum instance '#{node[:nova][:quantum_instance]}' for nova not found")
  else
     quantum = node
end

case quantum[:quantum][:networking_plugin]
when "openvswitch"
  quantum_agent=node[:quantum][:platform][:ovs_agent_name]
when "linuxbridge"
  quantum_agent=node[:quantum][:platform][:lb_agent_name]
end

quantum_path = "/opt/quantum"
venv_path = quantum[:quantum][:use_virtualenv] ? "#{quantum_path}/.venv" : nil

quantum_server = node[:quantum][:quantum_server] rescue false

env_filter = " AND keystone_config_environment:keystone-config-#{quantum[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones.first
  keystone = quantum if keystone.name == quantum.name
else
  keystone = quantum
end

if quantum[:quantum][:networking_plugin] == "openvswitch"
  node[:quantum][:platform][:ovs_pkgs].each { |p| package p }

  bash "Load openvswitch module" do
    code node[:quantum][:platform][:ovs_modprobe]
    not_if do ::File.directory?("/sys/module/openvswitch") end
  end
end

unless quantum[:quantum][:use_gitrepo]
  package quantum_agent do
    action :install
  end
else
  quantum_agent = "quantum-openvswitch-agent"
  pfs_and_install_deps "quantum" do
    cookbook "quantum"
    cnode quantum
    virtualenv venv_path
    path quantum_path
    wrap_bins [ "quantum", "quantum-rootwrap" ]
  end
  pfs_and_install_deps "keystone" do
    cookbook "keystone"
    cnode keystone
    path File.join(quantum_path,"keystone")
    virtualenv venv_path
  end

  create_user_and_dirs("quantum")

  link_service quantum_agent do
    virtualenv venv_path
    bin_name "quantum-openvswitch-agent --config-dir /etc/quantum/"
  end

  execute "quantum_cp_policy.json" do
    command "cp /opt/quantum/etc/policy.json /etc/quantum/"
    creates "/etc/quantum/policy.json"
  end
  execute "quantum_cp_rootwrap" do
    command "cp -r /opt/quantum/etc/quantum/rootwrap.d /etc/quantum/rootwrap.d"
    creates "/etc/quantum/rootwrap.d"
  end
  cookbook_file "/etc/quantum/rootwrap.conf" do
    cookbook "quantum"
    source "quantum-rootwrap.conf"
    mode 00644
    owner node[:quantum][:platform][:user]
  end
end

node[:quantum] ||= Mash.new
node.set[:quantum][:rootwrap] = "/usr/bin/quantum-rootwrap"

# Update path to quantum-rootwrap in case the path above is wrong
ruby_block "Find quantum rootwrap" do
  block do
    found = false
    ENV['PATH'].split(':').each do |p|
      f = File.join(p,"quantum-rootwrap")
      next unless File.executable?(f)
      node.set[:quantum][:rootwrap] = f
      found = true
      break
    end
    raise("Could not find quantum rootwrap binary!") unless found
  end
end

template "/etc/sudoers.d/quantum-rootwrap" do
  cookbook "quantum"
  source "quantum-rootwrap.erb"
  mode 0440
  variables(:user => node[:quantum][:platform][:user],
            :binary => node[:quantum][:rootwrap])
  not_if { node[:platform] == "suse" }
end

case quantum[:quantum][:networking_plugin]
when "openvswitch"

  service "openvswitch-switch" do
    supports :status => true, :restart => true
    action [ :enable ]
  end

  bash "Start openvswitch-switch service" do
    code "service openvswitch-switch start"
    only_if "service openvswitch-switch status |grep -q 'is not running'"
  end

  # We always need br-int.  Quantum uses this bridge internally.
  execute "create_int_br" do
    command "ovs-vsctl add-br br-int"
    not_if "ovs-vsctl list-br | grep -q br-int"
  end

  # Make sure br-int is always up.
  ruby_block "Bring up the internal bridge" do
    block do
      ::Nic.new('br-int').up
    end
  end

  # Create the bridges Quantum needs.
  # Usurp config as needed.
  [ [ "nova_fixed", "fixed" ],
    [ "os_sdn", "tunnel" ],
    [ "public", "public"] ].each do |net|
    bound_if = (node[:crowbar_wall][:network][:nets][net[0]].last rescue nil)
    next unless bound_if
    name = "br-#{net[1]}"
    execute "Quantum: create #{name}" do
      command "ovs-vsctl add-br #{name}; ip link set #{name} up"
      not_if "ovs-vsctl list-br |grep -q #{name}"
    end
    next if net[1] == "tunnel"
    execute "Quantum: add #{bound_if} to #{name}" do
      command "ovs-vsctl del-port #{name} #{bound_if} ; ovs-vsctl add-port #{name} #{bound_if}"
      not_if "ovs-dpctl show system@#{name} | grep -q #{bound_if}"
    end
    ruby_block "Have #{name} usurp config from #{bound_if}" do
      block do
        target = ::Nic.new(name)
        res = target.usurp(bound_if)
        Chef::Log.info("#{name} usurped #{res[0].join(", ")} addresses from #{bound_if}") unless res[0].empty?
        Chef::Log.info("#{name} usurped #{res[1].join(", ")} routes from #{bound_if}") unless res[1].empty?
      end
    end
  end
end

service quantum_agent do
  supports :status => true, :restart => true
  action :enable
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
if quantum[:quantum][:networking_mode] == 'vlan'
  per_tenant_vlan=true
else
  per_tenant_vlan=false
end

env_filter = " AND rabbitmq_config_environment:rabbitmq-config-#{quantum[:quantum][:rabbitmq_instance]}"
rabbits = search(:node, "roles:rabbitmq-server#{env_filter}") || []
if rabbits.length > 0
  rabbit = rabbits[0]
  rabbit = node if rabbit.name == node.name
else
  rabbit = node
end
rabbit_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(rabbit, "admin").address
Chef::Log.info("Rabbit server found at #{rabbit_address}")
rabbit_settings = {
  :address => rabbit_address,
  :port => rabbit[:rabbitmq][:port],
  :user => rabbit[:rabbitmq][:user],
  :password => rabbit[:rabbitmq][:password],
  :vhost => rabbit[:rabbitmq][:vhost]
}

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = quantum["quantum"]["service_user"]
keystone_service_password = quantum["quantum"]["service_password"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
Chef::Log.info("Keystone server found at #{keystone_address}")

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
vlan_end = vlan_start + 2000

case quantum[:quantum][:networking_plugin]
when "openvswitch"
  plugin_cfg_path = "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini"
  physnet = quantum[:quantum][:networking_mode] == 'gre' ? "br-tunnel" : "br-fixed"
  interface_driver = "quantum.agent.linux.interface.OVSInterfaceDriver"
  external_network_bridge = "br-public"
when "linuxbridge"
  plugin_cfg_path = "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"
  physnet = (node[:crowbar_wall][:network][:nets][:nova_fixed].first rescue nil)
  interface_driver = "quantum.agent.linux.interface.BridgeInterfaceDriver"
  external_network_bridge = ""
end

if quantum[:quantum][:use_gitrepo] == true
  plugin_cfg_path = File.join("/opt/quantum", plugin_cfg_path)
end

link plugin_cfg_path do
  to "/etc/quantum/quantum.conf"
  notifies :restart, resources(:service => quantum_agent), :immediately
end

template "/etc/quantum/quantum.conf" do
    cookbook "quantum"
    source "quantum.conf.erb"
    mode "0640"
    owner node[:quantum][:platform][:user]
    variables(
      :sql_connection => quantum[:quantum][:db][:sql_connection],
      :sql_idle_timeout => quantum[:quantum][:sql][:idle_timeout],
      :sql_min_pool_size => quantum[:quantum][:sql][:min_pool_size],
      :sql_max_pool_size => quantum[:quantum][:sql][:max_pool_size],
      :sql_pool_timeout => quantum[:quantum][:sql][:pool_timeout],
      :debug => quantum[:quantum][:debug],
      :verbose => quantum[:quantum][:verbose],
      :service_port => quantum[:quantum][:api][:service_port], # Compute port
      :service_host => quantum[:quantum][:api][:service_host],
      :use_syslog => quantum[:quantum][:use_syslog],
      :rabbit_settings => rabbit_settings,
      :keystone_protocol => keystone_protocol,
      :keystone_ip_address => keystone_address,
      :keystone_service_port => keystone_service_port,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_admin_port => keystone_admin_port,
      :metadata_address => metadata_address,
      :metadata_port => metadata_port,
      :ssl_enabled => quantum[:quantum][:api][:protocol] == 'https',
      :ssl_cert_file => quantum[:quantum][:ssl][:certfile],
      :ssl_key_file => quantum[:quantum][:ssl][:keyfile],
      :ssl_cert_required => quantum[:quantum][:ssl][:cert_required],
      :ssl_ca_file => quantum[:quantum][:ssl][:ca_certs],
      :quantum_server => quantum_server,
      :per_tenant_vlan => per_tenant_vlan,
      :networking_mode => quantum[:quantum][:networking_mode],
      :networking_plugin => quantum[:quantum][:networking_plugin],
      :vlan_start => vlan_start,
      :vlan_end => vlan_end,
      :physnet => physnet,
      :interface_driver => interface_driver,
      :external_network_bridge => external_network_bridge,
      :rootwrap_bin =>  quantum[:quantum][:rootwrap]
    )
    notifies :restart, resources(:service => quantum_agent), :immediately
end
