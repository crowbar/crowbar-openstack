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

neutron = nil
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = search(:node, "roles:neutron-server AND roles:neutron-config-#{node[:nova][:neutron_instance]}")
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
  else
     neutron = node
end

case neutron[:neutron][:networking_plugin]
when "openvswitch", "cisco"
  neutron_agent = node[:neutron][:platform][:ovs_agent_name]
  neutron_agent_pkg = node[:neutron][:platform][:ovs_agent_pkg]
  plugin_cfg_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"

  # Arrange for neutron-ovs-cleanup to be run on bootup of compute nodes only
  unless neutron.name == node.name
    cookbook_file "/etc/init.d/neutron-ovs-cleanup" do
      source "neutron-ovs-cleanup"
      mode 00755
    end

    link "/etc/rc2.d/S20neutron-ovs-cleanup" do
      to "../init.d/neutron-ovs-cleanup"
    end

    link "/etc/rc3.d/S20neutron-ovs-cleanup" do
      to "../init.d/neutron-ovs-cleanup"
    end

    link "/etc/rc4.d/S20neutron-ovs-cleanup" do
      to "../init.d/neutron-ovs-cleanup"
    end

    link "/etc/rc5.d/S20neutron-ovs-cleanup" do
      to "../init.d/neutron-ovs-cleanup"
    end
  end
when "linuxbridge"
  neutron_agent = node[:neutron][:platform][:lb_agent_name]
  neutron_agent_pkg = node[:neutron][:platform][:lb_agent_pkg]
  plugin_cfg_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
end

neutron_path = "/opt/neutron"
venv_path = neutron[:neutron][:use_virtualenv] ? "#{neutron_path}/.venv" : nil

neutron_server = node[:neutron][:neutron_server] rescue false

env_filter = " AND keystone_config_environment:keystone-config-#{neutron[:neutron][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones.first
  keystone = neutron if keystone.name == neutron.name
else
  keystone = neutron
end

if neutron[:neutron][:networking_plugin] == "openvswitch" or neutron[:neutron][:networking_plugin] == "cisco"

  if node.platform == "ubuntu"
    # If we expect to install the openvswitch module via DKMS, but the module
    # does not exist, rmmod the openvswitch module before continuing.
    if node[:neutron][:platform][:ovs_pkgs].any?{|e|e == "openvswitch-datapath-dkms"} &&
        !File.exists?("/lib/modules/#{%x{uname -r}.strip}/updates/dkms/openvswitch.ko") &&
        File.directory?("/sys/module/openvswitch")
      if IO.read("/sys/module/openvswitch/refcnt").strip != "0"
        Chef::Log.error("Kernel openvswitch module already loaded and in use! Please reboot me!")
      else
        bash "Unload non-DKMS openvswitch module" do
          code "rmmod openvswitch"
        end
      end
    end
  end

  node[:neutron][:platform][:ovs_pkgs].each { |p| package p }

  bash "Load openvswitch module" do
    code node[:neutron][:platform][:ovs_modprobe]
    not_if do ::File.directory?("/sys/module/openvswitch") end
  end
end

unless neutron[:neutron][:use_gitrepo]
  package neutron_agent_pkg do
    action :install
  end

  link plugin_cfg_path do
    to "/etc/neutron/neutron.conf"
  end 

else
  neutron_agent = "neutron-openvswitch-agent"
  pfs_and_install_deps "neutron" do
    cookbook "neutron"
    cnode neutron
    virtualenv venv_path
    path neutron_path
    wrap_bins [ "neutron", "neutron-rootwrap" ]
  end
  pfs_and_install_deps "keystone" do
    cookbook "keystone"
    cnode keystone
    path File.join(neutron_path,"keystone")
    virtualenv venv_path
  end

  create_user_and_dirs("neutron")

  link_service neutron_agent do
    virtualenv venv_path
    bin_name "neutron-openvswitch-agent --config-file #{plugin_cfg_path} --config-dir /etc/neutron/"
  end

  execute "neutron_cp_policy.json" do
    command "cp /opt/neutron/etc/policy.json /etc/neutron/"
    creates "/etc/neutron/policy.json"
  end
  execute "neutron_cp_plugins" do
    command "cp -r /opt/neutron/etc/neutron/plugins /etc/neutron/plugins"
    creates "/etc/neutron/plugins"
  end
  execute "neutron_cp_rootwrap" do
    command "cp -r /opt/neutron/etc/neutron/rootwrap.d /etc/neutron/rootwrap.d"
    creates "/etc/neutron/rootwrap.d"
  end
  cookbook_file "/etc/neutron/rootwrap.conf" do
    cookbook "neutron"
    source "neutron-rootwrap.conf"
    mode 00644
    owner node[:neutron][:platform][:user]
  end

  case neutron[:neutron][:networking_plugin]
  when "openvswitch"
    template plugin_cfg_path do
      cookbook "neutron"
      source "ovs_neutron_plugin.ini.erb"
      owner neutron[:neutron][:platform][:user]
      group "root"
      mode "0640"
      variables(
          :ovs_sql_connection => neutron[:neutron][:db][:sql_connection],
          :rootwrap_bin =>  node[:neutron][:rootwrap]
      )
    end
  when "linuxbridge"
    template plugin_cfg_path do
      cookbook "neutron"
      source "linuxbridge_conf.ini.erb"
      owner neutron[:neutron][:platform][:user]
      group "root"
      mode "0640"
      variables(
          :sql_connection => neutron[:neutron][:db][:sql_connection]
      )
    end
  end
end

node[:neutron] ||= Mash.new
if not node[:neutron].has_key?("rootwrap")
  unless neutron[:neutron][:use_gitrepo]
    node.set[:neutron][:rootwrap] = "/usr/bin/neutron-rootwrap"
  else
    node.set[:neutron][:rootwrap] = "/usr/local/bin/neutron-rootwrap"
  end
end

# Update path to neutron-rootwrap in case the path above is wrong
ruby_block "Find neutron rootwrap" do
  block do
    found = false
    ENV['PATH'].split(':').each do |p|
      f = File.join(p,"neutron-rootwrap")
      next unless File.executable?(f)
      node.set[:neutron][:rootwrap] = f
      node.save
      found = true
      break
    end
    raise("Could not find neutron rootwrap binary!") unless found
  end
end

template node[:neutron][:platform][:neutron_rootwrap_sudo_template] do
  cookbook "neutron"
  source "neutron-rootwrap.erb"
  mode 0440
  variables(:user => node[:neutron][:platform][:user],
            :binary => node[:neutron][:rootwrap])
end

case neutron[:neutron][:networking_plugin]
when "openvswitch", "cisco"
  plugin_cfg_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
  physnet = neutron[:neutron][:networking_mode] == 'gre' ? "br-tunnel" : "br-fixed"
  interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
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

  # We always need br-int.  Neutron uses this bridge internally.
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

  # Create the bridges Neutron needs.
  # Usurp config as needed.
  [ [ "nova_fixed", "fixed" ],
    [ "os_sdn", "tunnel" ],
    [ "public", "public"] ].each do |net|
    bound_if = (node[:crowbar_wall][:network][:nets][net[0]].last rescue nil)
    next unless bound_if
    name = "br-#{net[1]}"
    execute "Neutron: create #{name}" do
      command "ovs-vsctl add-br #{name}; ip link set #{name} up"
      not_if "ovs-vsctl list-br |grep -q #{name}"
    end
    next if net[1] == "tunnel"
    execute "Neutron: add #{bound_if} to #{name}" do
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
  physnet = (node[:crowbar_wall][:network][:nets][:nova_fixed].first rescue nil)
  interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
  external_network_bridge = ""
end

#env_filter = " AND nova_config_environment:nova-config-#{node[:tempest][:nova_instance]}"
#assuming we have only one nova
#TODO: nova should depend on neutron, but neutron depend on nova a bit, so we have to do somthing with this

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
if neutron[:neutron][:networking_mode] == 'vlan'
  per_tenant_vlan=true
else
  per_tenant_vlan=false
end

env_filter = " AND rabbitmq_config_environment:rabbitmq-config-#{neutron[:neutron][:rabbitmq_instance]}"
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
keystone_service_user = neutron["neutron"]["service_user"]
keystone_service_password = neutron["neutron"]["service_password"]
admin_username = keystone["keystone"]["admin"]["username"] rescue nil
admin_password = keystone["keystone"]["admin"]["password"] rescue nil
Chef::Log.info("Keystone server found at #{keystone_host}")

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
vlan_end = vlan_start + 2000

if %w(redhat centos).include?(node.platform)
 link "/etc/neutron/plugin.ini" do
   to "/etc/neutron/neutron.conf"
 end
end

if neutron_server and neutron[:neutron][:api][:protocol] == 'https'
  if neutron[:neutron][:ssl][:generate_certs]
    package "openssl"
    ruby_block "generate_certs for neutron" do
      block do
        unless ::File.exists? node[:neutron][:ssl][:certfile] and ::File.exists? node[:neutron][:ssl][:keyfile]
          require "fileutils"

          Chef::Log.info("Generating SSL certificate for neutron...")

          [:certfile, :keyfile].each do |k|
            dir = File.dirname(neutron[:neutron][:ssl][k])
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
          end

          # Generate private key
          %x(openssl genrsa -out #{neutron[:neutron][:ssl][:keyfile]} 4096)
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", neutron[:neutron][:group], neutron[:neutron][:ssl][:keyfile]
          FileUtils.chmod 0640, node[:neutron][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname neutron[:neutron][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{neutron[:fqdn]}\""
          %x(openssl req -new -key #{neutron[:neutron][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject})
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          %x(openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{neutron[:neutron][:ssl][:keyfile]} -out #{neutron[:neutron][:ssl][:certfile]})
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
    unless ::File.exists? neutron[:neutron][:ssl][:certfile]
      message = "Certificate \"#{neutron[:neutron][:ssl][:certfile]}\" is not present."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if neutron[:neutron][:ssl][:cert_required] and !::File.exists? neutron[:neutron][:ssl][:ca_certs]
    message = "Certificate CA \"#{neutron[:neutron][:ssl][:ca_certs]}\" is not present."
    Chef::Log.fatal(message)
    raise message
  end
end

template "/etc/neutron/neutron.conf" do
    cookbook "neutron"
    source "neutron.conf.erb"
    mode "0640"
    owner node[:neutron][:platform][:user]
    variables(
      :sql_connection => neutron[:neutron][:db][:sql_connection],
      :sql_min_pool_size => neutron[:neutron][:sql][:min_pool_size],
      :sql_max_pool_overflow => neutron[:neutron][:sql][:max_pool_overflow],
      :sql_pool_timeout => neutron[:neutron][:sql][:pool_timeout],
      :debug => neutron[:neutron][:debug],
      :verbose => neutron[:neutron][:verbose],
      :service_port => neutron[:neutron][:api][:service_port], # Compute port
      :service_host => neutron[:neutron][:api][:service_host],
      :use_syslog => neutron[:neutron][:use_syslog],
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
      :ssl_enabled => neutron[:neutron][:api][:protocol] == 'https',
      :ssl_cert_file => neutron[:neutron][:ssl][:certfile],
      :ssl_key_file => neutron[:neutron][:ssl][:keyfile],
      :ssl_cert_required => neutron[:neutron][:ssl][:cert_required],
      :ssl_ca_file => neutron[:neutron][:ssl][:ca_certs],
      :neutron_server => neutron_server,
      :per_tenant_vlan => per_tenant_vlan,
      :networking_mode => neutron[:neutron][:networking_mode],
      :networking_plugin => neutron[:neutron][:networking_plugin],
      :vlan_start => vlan_start,
      :vlan_end => vlan_end,
      :physnet => physnet,
      :interface_driver => interface_driver,
      :external_network_bridge => external_network_bridge,
      :rootwrap_bin =>  node[:neutron][:rootwrap]
    )
end

if neutron_server
  # no subscribes for :restart; this is handled by the
  # "mark neutron-agent as restart for post-install" ruby_block
  # but it only exists if we're also the server
  service neutron_agent do
    supports :status => true, :restart => true
    action :enable
  end
else
  service neutron_agent do
    supports :status => true, :restart => true
    action :enable
    subscribes :restart, resources("link[#{plugin_cfg_path}]") unless neutron[:neutron][:use_gitrepo]
    subscribes :restart, resources("template[#{plugin_cfg_path}]") if neutron[:neutron][:use_gitrepo]
    subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
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
  #neutron tries to use v6 ip utils but rhel not support for v6, so lets workaround this issue this way
  link "/sbin/ip6tables-restore" do
    to "/bin/true"
  end
  link "/sbin/ip6tables-save" do
    to "/bin/true"
  end
end

