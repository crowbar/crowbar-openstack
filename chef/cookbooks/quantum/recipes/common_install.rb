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
when "openvswitch", "cisco"
  quantum_agent = node[:quantum][:platform][:ovs_agent_name]
  quantum_agent_pkg = node[:quantum][:platform][:ovs_agent_pkg]
when "linuxbridge"
  quantum_agent = node[:quantum][:platform][:lb_agent_name]
  quantum_agent_pkg = node[:quantum][:platform][:lb_agent_pkg]
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

if quantum[:quantum][:networking_plugin] == "openvswitch" or quantum[:quantum][:networking_plugin] == "cisco"

  if node.platform == "ubuntu"
    # If we expect to install the openvswitch module via DKMS, but the module
    # does not exist, rmmod the openvswitch module before continuing.
    if node[:quantum][:platform][:ovs_pkgs].any?{|e|e == "openvswitch-datapath-dkms"} &&
        !File.exists?("/lib/modules/#{%x{uname -r}.strip}/updates/dkms/openvswitch.ko") &&
        File.directory?("/sys/module/openvswitch")
      if IO.read("/sys/module/openvswitch").strip != "0"
        Chef::Log.error("Kernel openvswitch module already loaded and in use! Please reboot me!")
      else
        bash "Unload non-DKMS openvswitch module" do
          code "rmmod openvswitch"
        end
      end
    end
  end

  node[:quantum][:platform][:ovs_pkgs].each { |p| package p }

  bash "Load openvswitch module" do
    code node[:quantum][:platform][:ovs_modprobe]
    not_if do ::File.directory?("/sys/module/openvswitch") end
  end
end

unless quantum[:quantum][:use_gitrepo]
  package quantum_agent_pkg do
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
if not node[:quantum].has_key?("rootwrap")
  unless quantum[:quantum][:use_gitrepo]
    node.set[:quantum][:rootwrap] = "/usr/bin/quantum-rootwrap"
  else
    node.set[:quantum][:rootwrap] = "/usr/local/bin/quantum-rootwrap"
  end
end

# Update path to quantum-rootwrap in case the path above is wrong
ruby_block "Find quantum rootwrap" do
  block do
    found = false
    ENV['PATH'].split(':').each do |p|
      f = File.join(p,"quantum-rootwrap")
      next unless File.executable?(f)
      node.set[:quantum][:rootwrap] = f
      node.save
      found = true
      break
    end
    raise("Could not find quantum rootwrap binary!") unless found
  end
end

template node[:quantum][:platform][:quantum_rootwrap_sudo_template] do
  cookbook "quantum"
  source "quantum-rootwrap.erb"
  mode 0440
  variables(:user => node[:quantum][:platform][:user],
            :binary => node[:quantum][:rootwrap])
end

case quantum[:quantum][:networking_plugin]
when "openvswitch", "cisco"
  plugin_cfg_path = "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini"
  physnet = quantum[:quantum][:networking_mode] == 'gre' ? "br-tunnel" : "br-fixed"
  interface_driver = "quantum.agent.linux.interface.OVSInterfaceDriver"
  external_network_bridge = "br-public"
  
  if %w(redhat centos).include?(node.platform)
    openvswitch_service = "openvswitch"
  else
    openvswitch_service = "openvswitch-switch"
  end
  service "openvswitch_service" do
    service_name openvswitch_service
    supports :status => true, :restart => true
    action [ :enable ]
  end

  bash "Start #{openvswitch_service} service" do
    code "service #{openvswitch_service} start"
    only_if "service #{openvswitch_service} status |grep -q 'is not running'"
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
when "linuxbridge"
  plugin_cfg_path = "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"
  physnet = (node[:crowbar_wall][:network][:nets][:nova_fixed].first rescue nil)
  interface_driver = "quantum.agent.linux.interface.BridgeInterfaceDriver"
  external_network_bridge = ""
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
# we use an IP address here, and not nova[:fqdn] because nova-metadata doesn't use SSL
# and because it listens on this specific IP address only (so we don't want to use a name
# that could resolve to 127.0.0.1).
metadata_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(nova, "admin").address
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

keystone_host = keystone[:fqdn]
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = quantum["quantum"]["service_user"]
keystone_service_password = quantum["quantum"]["service_password"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
Chef::Log.info("Keystone server found at #{keystone_host}")

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
vlan_end = vlan_start + 2000

if quantum[:quantum][:use_gitrepo] == true
  plugin_cfg_path = File.join("/opt/quantum", plugin_cfg_path)
end

link plugin_cfg_path do
  to "/etc/quantum/quantum.conf"
end

if %w(redhat centos).include?(node.platform)
 link "/etc/quantum/plugin.ini" do
   to "/etc/quantum/quantum.conf"
 end
end

if quantum_server and quantum[:quantum][:api][:protocol] == 'https'
  if quantum[:quantum][:ssl][:generate_certs]
    package "openssl"
    ruby_block "generate_certs for quantum" do
      block do
        unless ::File.exists? node[:quantum][:ssl][:certfile] and ::File.exists? node[:quantum][:ssl][:keyfile]
          require "fileutils"

          Chef::Log.info("Generating SSL certificate for quantum...")

          [:certfile, :keyfile].each do |k|
            dir = File.dirname(quantum[:quantum][:ssl][k])
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
          end

          # Generate private key
          %x(openssl genrsa -out #{quantum[:quantum][:ssl][:keyfile]} 4096)
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", quantum[:quantum][:group], quantum[:quantum][:ssl][:keyfile]
          FileUtils.chmod 0640, node[:quantum][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname quantum[:quantum][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{quantum[:fqdn]}\""
          %x(openssl req -new -key #{quantum[:quantum][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject})
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          %x(openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{quantum[:quantum][:ssl][:keyfile]} -out #{quantum[:quantum][:ssl][:certfile]})
          if $?.exitstatus != 0
            message = "SSL self-signed certificate generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          File.delete ssl_csr_file  # Nobody should even try to use this
        end # unless files exist
      end # block
    end # ruby_block
  else # if generate_certs
    unless ::File.exists? quantum[:quantum][:ssl][:certfile]
      message = "Certificate \"#{quantum[:quantum][:ssl][:certfile]}\" is not present."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if quantum[:quantum][:ssl][:cert_required] and !::File.exists? quantum[:quantum][:ssl][:ca_certs]
    message = "Certificate CA \"#{quantum[:quantum][:ssl][:ca_certs]}\" is not present."
    Chef::Log.fatal(message)
    raise message
  end
end

template "/etc/quantum/quantum.conf" do
    cookbook "quantum"
    source "quantum.conf.erb"
    mode "0640"
    owner node[:quantum][:platform][:user]
    variables(
      :sql_connection => quantum[:quantum][:db][:sql_connection],
      :sql_min_pool_size => quantum[:quantum][:sql][:min_pool_size],
      :sql_max_pool_overflow => quantum[:quantum][:sql][:max_pool_overflow],
      :sql_pool_timeout => quantum[:quantum][:sql][:pool_timeout],
      :debug => quantum[:quantum][:debug],
      :verbose => quantum[:quantum][:verbose],
      :service_port => quantum[:quantum][:api][:service_port], # Compute port
      :service_host => quantum[:quantum][:api][:service_host],
      :use_syslog => quantum[:quantum][:use_syslog],
      :rabbit_settings => rabbit_settings,
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_service_port => keystone_service_port,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_admin_port => keystone_admin_port,
      :metadata_host => metadata_host,
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
      :rootwrap_bin =>  node[:quantum][:rootwrap]
    )
end

if quantum_server
  # no subscribes for :restart; this is handled by the
  # "mark quantum-agent as restart for post-install" ruby_block
  # but it only exists if we're also the server
  service quantum_agent do
    supports :status => true, :restart => true
    action :enable
  end
else
  service quantum_agent do
    supports :status => true, :restart => true
    action :enable
    subscribes :restart, resources("link[#{plugin_cfg_path}]")
    subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  end
end


if %w(redhat centos).include?(node.platform)
  net_core_pkgs=%w(kernel iproute iputils)

  ruby_block "unset_reboot" do
    block do
      node.set[:reboot] = "complete"
      node.save
    end
    action :create
  end

  ruby_block "set_reboot" do
    block do
      node.set[:reboot] = "require"
      node.save
    end
    action :create
    not_if "uname -a | grep 'openstack'"
  end

  net_core_pkgs.each do |pkg|
    package "#{pkg}" do
      action :upgrade
      notifies :create, "ruby_block[set_reboot]"
    end
  end
  #quantum tries to use v6 ip utils but rhel not support for v6, so lets workaround this issue this way
  link "/sbin/ip6tables-restore" do
    to "/bin/true"
  end
  link "/sbin/ip6tables-save" do
    to "/bin/true"
  end
end

