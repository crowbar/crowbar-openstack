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

template neutron[:neutron][:platform][:neutron_rootwrap_sudo_template] do
  cookbook "neutron"
  source "neutron-rootwrap.erb"
  mode 0440
  variables(user: neutron[:neutron][:platform][:user],
            binary: "/usr/bin/neutron-rootwrap")
  not_if { node[:platform_family] == "suse" }
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

#TODO: nova should depend on neutron, but neutron also depends on nova
# so we have to do something like this
novas = search(:node, "roles:nova-multi-controller") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end
nova_notify = {}

unless nova[:nova].nil? or nova[:nova][:ssl].nil?
  nova_api_host = CrowbarHelper.get_host_for_admin_url(nova, (nova[:nova][:ha][:enabled] rescue false))
  nova_api_protocol = nova[:nova][:ssl][:enabled] ? "https" : "http"
  nova_insecure = keystone_settings["insecure"] || (nova[:nova][:ssl][:enabled] && nova[:nova][:ssl][:insecure])

  nova_notify = {
    nova_url: "#{nova_api_protocol}://#{nova_api_host}:#{nova[:nova][:ports][:api]}/v2",
    nova_insecure: nova_insecure,
    nova_admin_username: nova[:nova][:service_user],
    nova_admin_tenant_id: keystone_settings["service_tenant_id"],
    nova_admin_password: nova[:nova][:service_password]
  }
end

service_plugins = "neutron.services.metering.metering_plugin.MeteringPlugin"
service_plugins = "#{service_plugins}, neutron.services.firewall.fwaas_plugin.FirewallPlugin"
if neutron[:neutron][:use_lbaas] then
  service_plugins = "#{service_plugins}, neutron.services.loadbalancer.plugin.LoadBalancerPlugin"
end

network_nodes_count = neutron[:neutron][:elements]["neutron-network"].count
if neutron[:neutron][:elements_expanded]
  network_nodes_count = neutron[:neutron][:elements_expanded]["neutron-network"].count
end

template "/etc/neutron/neutron.conf" do
    cookbook "neutron"
    source "neutron.conf.erb"
    mode "0640"
    owner "root"
    group neutron[:neutron][:platform][:group]
    variables({
      sql_connection: neutron[:neutron][:db][:sql_connection],
      sql_min_pool_size: neutron[:neutron][:sql][:min_pool_size],
      sql_max_pool_overflow: neutron[:neutron][:sql][:max_pool_overflow],
      sql_pool_timeout: neutron[:neutron][:sql][:pool_timeout],
      debug: neutron[:neutron][:debug],
      verbose: neutron[:neutron][:verbose],
      bind_host: bind_host,
      bind_port: bind_port,
      use_syslog: neutron[:neutron][:use_syslog],
      # Note that we don't uset fetch_rabbitmq_settings, as we want to run the
      # query on the "neutron" node, not on "node"
      rabbit_settings: CrowbarOpenStackHelper.rabbitmq_settings(neutron, "neutron"),
      keystone_settings: keystone_settings,
      ssl_enabled: neutron[:neutron][:api][:protocol] == "https",
      ssl_cert_file: neutron[:neutron][:ssl][:certfile],
      ssl_key_file: neutron[:neutron][:ssl][:keyfile],
      ssl_cert_required: neutron[:neutron][:ssl][:cert_required],
      ssl_ca_file: neutron[:neutron][:ssl][:ca_certs],
      core_plugin: neutron[:neutron][:networking_plugin],
      service_plugins: service_plugins,
      use_namespaces: true,
      allow_overlapping_ips: neutron[:neutron][:allow_overlapping_ips],
      dvr_enabled: neutron[:neutron][:use_dvr],
      network_nodes_count: network_nodes_count
    }.merge(nova_notify))
end

if node[:platform_family] == "rhel"
  link "/etc/neutron/plugin.ini" do
    to "/etc/neutron/neutron.conf"
  end
end

