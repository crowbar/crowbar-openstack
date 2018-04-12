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

is_neutron_server = node.roles.include?("neutron-server")

neutron = nil
if node.attribute?(:cookbook) and node[:cookbook] == "nova"
  neutrons = node_search_with_cache("roles:neutron-server", node[:nova][:neutron_instance])
  neutron = neutrons.first || raise("Neutron instance '#{node[:nova][:neutron_instance]}' for nova not found")
else
  neutron = node
end

use_apic_gbp = neutron[:neutron][:networking_plugin] == "ml2" &&
  neutron[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")

# RDO package magic (non-standard packages)
if node[:platform_family] == "rhel"
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

keystone_settings = KeystoneHelper.keystone_settings(neutron, @cookbook_name)

ha_enabled = node[:neutron][:ha][:server][:enabled]
memcached_servers = MemcachedHelper.get_memcached_servers(
  ha_enabled ? CrowbarPacemakerHelper.cluster_nodes(node, "neutron-server") : [node]
)

memcached_instance("neutron-server") if is_neutron_server

bind_host, bind_port = NeutronHelper.get_bind_host_port(node)

nova_config = Barclamp::Config.load("openstack", "nova")
nova_insecure = CrowbarOpenStackHelper.insecure(nova_config) || keystone_settings["insecure"]

service_plugins = ["neutron.services.metering.metering_plugin.MeteringPlugin",
                   "neutron_fwaas.services.firewall.fwaas_plugin.FirewallPlugin"]
if neutron[:neutron][:use_lbaas]
  service_plugins.push("neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2")
end

if neutron[:neutron][:networking_plugin] == "ml2"
  service_plugins.unshift("neutron.services.l3_router.l3_router_plugin.L3RouterPlugin")

  if neutron[:neutron][:ml2_mechanism_drivers].include?("linuxbridge") ||
      neutron[:neutron][:ml2_mechanism_drivers].include?("openvswitch")
    service_plugins.push("neutron.services.trunk.plugin.TrunkPlugin")
  end

  if neutron[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2")
    service_plugins = ["cisco_apic_l3"]
  elsif neutron[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")
    service_plugins = ["group_policy", "servicechain", "apic_gbp_l3"]
  end
end
service_plugins = service_plugins.join(", ")

network_nodes_count = neutron[:neutron][:elements]["neutron-network"].count
if neutron[:neutron][:elements_expanded]
  network_nodes_count = neutron[:neutron][:elements_expanded]["neutron-network"].count
end

os_sdn_net = Barclamp::Inventory.get_network_definition(node, "os_sdn")
mtu_value = os_sdn_net.nil? ? 1500 : os_sdn_net["mtu"].to_i

ipam_driver = nil
infoblox_settings = nil

if neutron[:neutron][:use_infoblox]
  ipam_driver = "infoblox"
  infoblox_settings = neutron[:neutron][:infoblox]
end

template neutron[:neutron][:config_file] do
    cookbook "neutron"
    source "neutron.conf.erb"
    mode "0640"
    owner "root"
    group neutron[:neutron][:platform][:group]
    variables(
      sql_connection: is_neutron_server ? neutron[:neutron][:db][:sql_connection] : nil,
      sql_min_pool_size: neutron[:neutron][:sql][:min_pool_size],
      sql_max_pool_overflow: neutron[:neutron][:sql][:max_pool_overflow],
      sql_pool_timeout: neutron[:neutron][:sql][:pool_timeout],
      debug: neutron[:neutron][:debug],
      bind_host: bind_host,
      bind_port: bind_port,
      use_syslog: neutron[:neutron][:use_syslog],
      # Note that we don't uset fetch_rabbitmq_settings, as we want to run the
      # query on the "neutron" node, not on "node"
      rabbit_settings: CrowbarOpenStackHelper.rabbitmq_settings(neutron, "neutron"),
      keystone_settings: keystone_settings,
      memcached_servers: memcached_servers,
      ssl_enabled: neutron[:neutron][:api][:protocol] == "https",
      ssl_cert_file: neutron[:neutron][:ssl][:certfile],
      ssl_key_file: neutron[:neutron][:ssl][:keyfile],
      ssl_cert_required: neutron[:neutron][:ssl][:cert_required],
      ssl_ca_file: neutron[:neutron][:ssl][:ca_certs],
      nova_insecure: nova_insecure,
      core_plugin: neutron[:neutron][:networking_plugin],
      service_plugins: service_plugins,
      allow_overlapping_ips: neutron[:neutron][:allow_overlapping_ips],
      dvr_enabled: neutron[:neutron][:use_dvr],
      network_nodes_count: network_nodes_count,
      dns_domain: neutron[:neutron][:dns_domain],
      mtu_value: mtu_value,
      infoblox: infoblox_settings,
      ipam_driver: ipam_driver,
      rpc_workers: neutron[:neutron][:rpc_workers],
      use_apic_gbp: use_apic_gbp
    )
end

if neutron[:neutron][:use_lbaas]
  interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"
  if neutron[:neutron][:networking_plugin] == "ml2" &&
      neutron[:neutron][:ml2_mechanism_drivers].include?("linuxbridge")
    interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
  end

  template neutron[:neutron][:lbaas_config_file] do
    source "neutron_lbaas.conf.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      interface_driver: interface_driver,
      use_lbaas: neutron[:neutron][:use_lbaas],
      lbaasv2_driver: neutron[:neutron][:lbaasv2_driver],
      keystone_settings: keystone_settings
    )
  end
end

if node[:platform_family] == "rhel"
  link "/etc/neutron/plugin.ini" do
    to node[:neutron][:config_file]
  end
end

