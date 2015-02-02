# Copyright 2013 Dell, Inc.
# Copyright 2014-2015 SUSE Linux GmbH
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

# RDO package magic (non-standard packages)
if %w(redhat centos).include?(node.platform)
  net_core_pkgs=%w(kernel-*openstack* iproute-*el6ost.netns* iputils)

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
    # calling yum manually because a regexp is used for some packages
    bash "install net pkgs" do
      user "root"
      code "yum install -d0 -e0 -y #{pkg}"
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

template neutron[:neutron][:platform][:neutron_rootwrap_sudo_template] do
  cookbook "neutron"
  source "neutron-rootwrap.erb"
  mode 0440
  variables(:user => neutron[:neutron][:platform][:user],
            :binary => node[:neutron][:rootwrap])
  not_if { node.platform == "suse" }
end


keystone_settings = KeystoneHelper.keystone_settings(neutron, @cookbook_name)

if neutron[:neutron][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(neutron, "admin").address
  bind_host = admin_address
  bind_port = neutron[:neutron][:ha][:ports][:server]
else
  bind_host = neutron[:neutron][:api][:service_host]
  bind_port = neutron[:neutron][:api][:service_port]
end

nova = get_instance("roles:nova-multi-controller")
nova_notify = {}

unless nova[:nova].nil? or nova[:nova][:ssl].nil?
  nova_api_host = CrowbarHelper.get_host_for_admin_url(nova, (nova[:nova][:ha][:enabled] rescue false))
  nova_api_protocol = nova[:nova][:ssl][:enabled] ? "https" : "http"
  keystone_insecure = keystone_settings['insecure'] ? "--insecure" : ""
  nova_insecure = nova[:nova][:ssl][:enabled] && nova[:nova][:ssl][:insecure]
  nova_ssl_cacerts = nova[:nova][:ssl][:ca_certs] unless nova_insecure

  nova_admin_tenant_id = %x[keystone --os_username '#{keystone_settings['admin_user']}' --os_password '#{keystone_settings['admin_password']}' --os_tenant_name '#{keystone_settings['admin_tenant']}' --os_auth_url '#{keystone_settings['internal_auth_url']}' --os_region_name '#{keystone_settings['endpoint_region']}' #{keystone_insecure} tenant-get '#{keystone_settings['service_tenant']}' | awk '/id/  { print $4 }'].chomp

  nova_notify = {
    :nova_url => "#{nova_api_protocol}://#{nova_api_host}:#{nova[:nova][:ports][:api]}/v2",
    :nova_insecure => nova_insecure,
    :nova_ssl_cacerts => nova_ssl_cacerts,
    :nova_admin_username => nova[:nova][:service_user],
    :nova_admin_tenant_id => nova_admin_tenant_id,
    :nova_admin_password => nova[:nova][:service_password]
  }
end

service_plugins = "neutron.services.metering.metering_plugin.MeteringPlugin"
service_plugins = "#{service_plugins}, neutron.services.firewall.fwaas_plugin.FirewallPlugin"
if neutron[:neutron][:use_lbaas] then
  service_plugins = "#{service_plugins}, neutron.services.loadbalancer.plugin.LoadBalancerPlugin"
end

template "/etc/neutron/neutron.conf" do
    cookbook "neutron"
    source "neutron.conf.erb"
    mode "0640"
    owner "root"
    group neutron[:neutron][:platform][:group]
    variables({
      :sql_connection => neutron[:neutron][:db][:sql_connection],
      :sql_min_pool_size => neutron[:neutron][:sql][:min_pool_size],
      :sql_max_pool_overflow => neutron[:neutron][:sql][:max_pool_overflow],
      :sql_pool_timeout => neutron[:neutron][:sql][:pool_timeout],
      :debug => neutron[:neutron][:debug],
      :verbose => neutron[:neutron][:verbose],
      :bind_host => bind_host,
      :bind_port => bind_port,
      :use_syslog => neutron[:neutron][:use_syslog],
      # Note that we don't uset fetch_rabbitmq_settings, as we want to run the
      # query on the "neutron" node, not on "node"
      :rabbit_settings => CrowbarOpenStackHelper.rabbitmq_settings(neutron, "neutron"),
      :keystone_settings => keystone_settings,
      :ssl_enabled => neutron[:neutron][:api][:protocol] == 'https',
      :ssl_cert_file => neutron[:neutron][:ssl][:certfile],
      :ssl_key_file => neutron[:neutron][:ssl][:keyfile],
      :ssl_cert_required => neutron[:neutron][:ssl][:cert_required],
      :ssl_ca_file => neutron[:neutron][:ssl][:ca_certs],
      :core_plugin => neutron[:neutron][:networking_plugin],
      :service_plugins => service_plugins,
      :rootwrap_bin =>  node[:neutron][:rootwrap],
      :use_namespaces => true,
      :allow_overlapping_ips => node[:neutron][:allow_overlapping_ips]
    }.merge(nova_notify))
end

if %w(redhat centos).include?(node.platform)
  link "/etc/neutron/plugin.ini" do
    to "/etc/neutron/neutron.conf"
  end
end

case neutron[:neutron][:networking_plugin]
when 'ml2'
  ml2_mech_drivers = neutron[:neutron][:ml2_mechanism_drivers]
  case
  when ml2_mech_drivers.include?("openvswitch")
    agent_config_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"

    directory "/etc/neutron/plugins/openvswitch/" do
      mode 00755
      owner "root"
      group neutron[:neutron][:platform][:group]
      action :create
      recursive true
      not_if { node[:platform] == "suse" }
    end

    template agent_config_path do
      cookbook "neutron"
      source "ovs_neutron_plugin.ini.erb"
      owner "root"
      group neutron[:neutron][:platform][:group]
      mode "0640"
      variables(
        :ml2_type_drivers => neutron[:neutron][:ml2_type_drivers]
      )
    end
  when ml2_mech_drivers.include?("linuxbridge")
    agent_config_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"

    directory "/etc/neutron/plugins/linuxbridge/" do
      mode 00755
      owner "root"
      group neutron[:neutron][:platform][:group]
      action :create
      recursive true
      not_if { node[:platform] == "suse" }
    end

    template agent_config_path do
      cookbook "neutron"
      source "linuxbridge_conf.ini.erb"
      owner "root"
      group neutron[:neutron][:platform][:group]
      mode "0640"
      variables(
        :physnet => (node[:crowbar_wall][:network][:nets][:nova_fixed].first rescue nil)
      )
    end
  end
when "vmware"
  agent_config_path = "/etc/neutron/plugins/vmware/nsx.ini"

  directory "/etc/neutron/plugins/vmware/" do
     mode 00755
     owner "root"
     group neutron[:neutron][:platform][:group]
     action :create
     recursive true
     not_if { node[:platform] == "suse" }
  end

  template agent_config_path do
    cookbook "neutron"
    source "nsx.ini.erb"
    owner "root"
    group neutron[:neutron][:platform][:group]
    mode "0640"
    variables(
      :vmware_config => neutron[:neutron][:vmware]
      )
  end

end
