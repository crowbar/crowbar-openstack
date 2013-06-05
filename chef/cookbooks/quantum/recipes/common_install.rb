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

quantum_agent=node[:quantum][:platform][:ovs_agent_name]

quantum_path = "/opt/quantum"
venv_path = quantum[:quantum][:use_virtualenv] ? "#{quantum_path}/.venv" : nil
venv_prefix = quantum[:quantum][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil

quantum_server = node[:quantum][:quantum_server] rescue false

env_filter = " AND keystone_config_environment:keystone-config-#{quantum[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones.first
  keystone = quantum if keystone.name == quantum.name
else
  keystone = quantum
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

ruby_block "Find quantum rootwrap" do
  block do
    ENV['PATH'].split(':').each do |p|
      f = File.join(p,"quantum-rootwrap")
      next unless File.executable?(f)
      node[:quantum] ||= Mash.new
      node[:quantum][:rootwrap] = f
      break
    end
    raise("Could not find quantum rootwrap binary!") unless node[:quantum][:rootwrap]
  end
end unless node[:quantum][:rootwrap] && !node[:quantum][:rootwrap].empty?

template "/etc/sudoers.d/quantum-rootwrap" do
  cookbook "quantum"
  source "quantum-rootwrap.erb"
  mode 0440
  variables(:user => "quantum",
            :binary => node[:quantum][:rootwrap])
end

node[:quantum][:platform][:ovs_pkgs].each { |p| package p }

bash "Load openvswitch module" do
  code node[:quantum][:platform][:ovs_modprobe]
  not_if do ::File.directory?("/sys/module/openvswitch") end
end

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
keystone_token = keystone["keystone"]["service"]["token"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = quantum["quantum"]["service_user"]
keystone_service_password = quantum["quantum"]["service_password"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
default_tenant = keystone["keystone"]["default"]["tenant"] rescue nil
Chef::Log.info("Keystone server found at #{keystone_address}")

service quantum_agent do
  supports :status => true, :restart => true
  action :enable
end

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
vlan_end = vlan_start + 2000

link "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini" do
  to "/etc/quantum/quantum.conf"
  notifies :restart, resources(:service => quantum_agent), :immediately
  notifies :restart, resources(:service => "openvswitch-switch"), :immediately
end

template "/etc/quantum/quantum.conf" do
    cookbook "quantum"
    source "quantum.conf.erb"
    mode "0644"
    owner node[:quantum][:platform][:user]
    variables(
      :sql_connection => quantum[:quantum][:db][:sql_connection],
      :sql_idle_timeout => quantum[:quantum][:sql][:idle_timeout],
      :sql_min_pool_size => quantum[:quantum][:sql][:min_pool_size],
      :sql_max_pool_size => quantum[:quantum][:sql][:max_pool_size],
      :sql_pool_timeout => quantum[:quantum][:sql][:pool_timeout],
      :debug => quantum[:quantum][:debug],
      :verbose => quantum[:quantum][:verbose],
      :admin_token => quantum[:quantum][:service][:token],
      :service_port => quantum[:quantum][:api][:service_port], # Compute port
      :service_host => quantum[:quantum][:api][:service_host],
      :use_syslog => quantum[:quantum][:use_syslog],
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
      :quantum_server => quantum_server,
      :per_tenant_vlan => per_tenant_vlan,
      :networking_mode => quantum[:quantum][:networking_mode],
      :vlan_start => vlan_start,
      :vlan_end => vlan_end,
      :physnet => quantum[:quantum][:networking_mode] == 'gre' ? "br-tunnel" : "br-fixed",
      :rootwrap_bin =>  quantum[:quantum][:rootwrap]
    )
    notifies :restart, resources(:service => quantum_agent), :immediately
end
