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

hyperv_compute_node = search(:node, "roles:nova-compute-hyperv") || []
use_hyperv = node[:neutron][:networking_plugin] == "ml2" && !hyperv_compute_node.empty?
zvm_compute_node = search(:node, "roles:nova-compute-zvm") || []
use_zvm = node[:neutron][:networking_plugin] == "ml2" && !zvm_compute_node.empty?
use_vmware_dvs = node[:neutron][:networking_plugin] == "ml2" &&
  node[:neutron][:ml2_mechanism_drivers].include?("vmware_dvs")

pkgs = node[:neutron][:platform][:pkgs] + node[:neutron][:platform][:pkgs_fwaas]
pkgs += node[:neutron][:platform][:pkgs_lbaas] if node[:neutron][:use_lbaas]
pkgs += node[:neutron][:platform][:infoblox_pkgs] if node[:neutron][:use_infoblox]

if use_hyperv
  pkgs << node[:neutron][:platform][:hyperv_pkg]
end
if use_zvm
  pkgs << node[:neutron][:platform][:zvm_agent_pkg]
end
use_vmware_dvs && pkgs << node[:neutron][:platform][:vmware_vsphere_pkg]

pkgs.each { |p| package p }

include_recipe "neutron::database"

if node[:neutron][:api][:protocol] == "https"
  ssl_setup "setting up ssl for neutron" do
    generate_certs node[:neutron][:ssl][:generate_certs]
    certfile node[:neutron][:ssl][:certfile]
    keyfile node[:neutron][:ssl][:keyfile]
    group node[:neutron][:group]
    fqdn node[:fqdn]
    cert_required node[:neutron][:ssl][:cert_required]
    ca_certs node[:neutron][:ssl][:ca_certs]
  end
end

include_recipe "neutron::common_config"

# remove unused plugin config snippets
all_plugin_snippets = [node[:neutron][:ml2_config_file], node[:neutron][:nsx_config_file]]
used_plugin_snippets = []
if node[:neutron][:networking_plugin] == "vmware"
  used_plugin_snippets << node[:neutron][:nsx_config_file]
else
  used_plugin_snippets << node[:neutron][:ml2_config_file]
end

(all_plugin_snippets - used_plugin_snippets).each do |config_file|
  file config_file do
    action :delete
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
end

# Empty the config file that is explicitly passed to neutron-server.
# This allows overriding of plugin settings using config snippets.
# NOTE: if plugin.ini is a symlink it will not replace it with regular file
#       but this is OK since all possible target files will be empty too.
file "/etc/neutron/plugin.ini" do
  owner "root"
  group node[:neutron][:platform][:group]
  mode "0640"
  content "# Please use config file snippets in /etc/neutron/neutron.conf.d/.\n" \
          "# See /etc/neutron/README.config for more details.\n"
end

# enable/disable ml2_conf_cisco for neutron-server
if node[:neutron][:networking_plugin] == "ml2" and
  node[:neutron][:ml2_mechanism_drivers].include?("cisco_nexus")
  cisco_nexus_link_action = "create"
else
  cisco_nexus_link_action = "delete"
end
link "/etc/neutron/neutron-server.conf.d/100-ml2_conf_cisco.ini.conf" do
  to "/etc/neutron/plugins/ml2/ml2_conf_cisco.ini"
  action cisco_nexus_link_action
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

# enable/disable ml2_conf_cisco_apic for neutron-server
if node[:neutron][:networking_plugin] == "ml2" &&
  (node[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2") ||
   node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp"))
  cisco_apic_link_action = "create"
else
  cisco_apic_link_action = "delete"
end
link "/etc/neutron/neutron-server.conf.d/100-ml2_conf_cisco_apic.ini.conf" do
  to "/etc/neutron/plugins/ml2/ml2_conf_cisco_apic.ini"
  action cisco_apic_link_action
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

directory "/var/cache/neutron" do
  owner node[:neutron][:user]
  group node[:neutron][:group]
  mode 0755
  action :create
  only_if { node[:platform_family] == "debian" }
end

# accessing the network definition directly, since the node is not using this
# network
fixed_net_def = Barclamp::Inventory.get_network_definition(node, "nova_fixed")
vlan_start = fixed_net_def["vlan"]
num_vlans = node[:neutron][:num_vlans]
vlan_end = [vlan_start + num_vlans - 1, 4094].min

gre_start = [node[:neutron][:gre][:tunnel_id_start], 1].max
gre_end = [node[:neutron][:gre][:tunnel_id_end], 2147483647].min

vni_start = [node[:neutron][:vxlan][:vni_start], 0].max
vni_end = [node[:neutron][:vxlan][:vni_end], 16777215].min

directory "/etc/neutron/plugins/ml2" do
  mode 0755
  action :create
  only_if { node[:platform_family] == "debian" }
end

# NOTE(toabctl): tenant_network types should have as first element 'ml2_type_drivers_default_tenant_network' and then the rest of the selected type drivers.
#                when creating tenant networks, it's not possible to manually select the network type. Neutron just tries every selected type until success
#                so the order is important
tenant_network_types = [[node[:neutron][:ml2_type_drivers_default_tenant_network]] + node[:neutron][:ml2_type_drivers]].flatten.uniq

interface_driver = "neutron.agent.linux.interface.OVSInterfaceDriver"

ironic_net = Barclamp::Inventory.get_network_definition(node, "ironic")

case node[:neutron][:networking_plugin]
when "ml2"
  # Find out which physical interfaces we need to define in the config (depends
  # on whether one of the external networks will share the physical interface
  # with "nova_fixed".
  external_networks = ["nova_floating"]

  # add ironic to external_networks if ironic network is configured
  external_networks << "ironic" if ironic_net

  external_networks.concat(node[:neutron][:additional_external_networks])
  network_node = NeutronHelper.get_network_node_from_neutron_attributes(node)
  physnet_map = NeutronHelper.get_neutron_physnets(network_node, external_networks)
  physnets = physnet_map.values

  if use_zvm
    physnets.push(node[:neutron][:zvm][:zvm_xcat_mgt_vswitch])
  end

  os_sdn_net = Barclamp::Inventory.get_network_definition(node, "os_sdn")
  mtu_value = os_sdn_net.nil? ? 1500 : os_sdn_net["mtu"].to_i

  ml2_extension_drivers = ["dns", "port_security"]
  ml2_type_drivers = node[:neutron][:ml2_type_drivers]
  ml2_mechanism_drivers = node[:neutron][:ml2_mechanism_drivers].dup
  if use_hyperv
    ml2_mechanism_drivers.push("hyperv")
  end
  if use_zvm
    ml2_mechanism_drivers.push("zvm")
  end
  if node[:neutron][:use_l2pop] &&
      (ml2_type_drivers.include?("gre") || ml2_type_drivers.include?("vxlan"))
    ml2_mechanism_drivers.push("l2population")
  end
  if use_vmware_dvs
    # If enabled, vmware_dvs needs to come before all others, otherwise the wrong
    # type of VIF will be used when launching server instances
    ml2_mechanism_drivers.unshift(ml2_mechanism_drivers.delete("vmware_dvs"))
  end

  ml2_mech_drivers = node[:neutron][:ml2_mechanism_drivers]
  if ml2_mech_drivers.include?("linuxbridge")
    interface_driver = "neutron.agent.linux.interface.BridgeInterfaceDriver"
  end

  # Empty the config file that is explicitly passed to neutron-server (via plugin.ini
  # symlink). This allows overriding of ml2_conf.ini settings using config snippets.
  file "/etc/neutron/plugins/ml2/ml2_conf.ini" do
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    content "# Please use config file snippets in /etc/neutron/neutron.conf.d/.\n" \
            "# See /etc/neutron/README.config for more details.\n"
  end

  template node[:neutron][:ml2_config_file] do
    source "ml2_conf.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      ml2_mechanism_drivers: ml2_mechanism_drivers,
      ml2_extension_drivers: ml2_extension_drivers,
      ml2_type_drivers: ml2_type_drivers,
      tenant_network_types: tenant_network_types,
      vlan_start: vlan_start,
      vlan_end: vlan_end,
      gre_start: gre_start,
      gre_end: gre_end,
      vxlan_start: vni_start,
      vxlan_end: vni_end,
      vxlan_mcast_group: node[:neutron][:vxlan][:multicast_group],
      external_networks: physnets,
      mtu_value: mtu_value,
      l2pop_agent_boot_time: node[:neutron][:l2pop][:agent_boot_time],
      vmware_dvs_config: node[:neutron][:vmware_dvs]
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
when "vmware"
  directory "/etc/neutron/plugins/vmware/" do
     mode 00755
     owner "root"
     group node[:neutron][:platform][:group]
     action :create
     recursive true
     not_if { node[:platform_family] == "suse" }
  end

  # Empty the config file that is explicitly passed to neutron-server (via plugin.ini
  # symlink). This allows overriding of nsx.ini settings using config snippets.
  file "/etc/neutron/plugins/vmware/nsx.ini" do
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    content "# Please use config file snippets in /etc/neutron/neutron.conf.d/.\n" \
            "# See /etc/neutron/README.config for more details.\n"
  end

  template node[:neutron][:nsx_config_file] do
    cookbook "neutron"
    source "nsx.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      vmware_config: node[:neutron][:vmware]
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
end

if node[:neutron][:networking_plugin] == "ml2"
  if node[:neutron][:ml2_mechanism_drivers].include?("cisco_nexus")
    include_recipe "neutron::cisco_support"
  elsif node[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2") ||
      node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")
    include_recipe "neutron::cisco_apic_support"
  end
end

if node[:neutron][:use_lbaas]
  template node[:neutron][:lbaas_service_file] do
    source "services_lbaas.conf.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      interface_driver: interface_driver
    )
    notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
  end
end

ha_enabled = node[:neutron][:ha][:server][:enabled]

# use an increased timeout here because there are plenty of db syncs
# inside of the sync mark and also a neutron-server start/stop
crowbar_pacemaker_sync_mark "wait sync mark for neutron db sync" do
  mark "neutron_db_sync"
  action :wait
  timeout 300
  only_if { ha_enabled }
end

execute "neutron-db-manage migrate" do
  user node[:neutron][:user]
  group node[:neutron][:group]
  command "neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head"
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:neutron][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

if ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node) && !node[:neutron][:db_synced]
  # Unfortunately, on first start, neutron populates the database. This is racy
  # in the HA case and causes failures to start. So we work around this by
  # quickly starting and stopping the service.
  # https://bugs.launchpad.net/neutron/+bug/1326634
  # https://bugzilla.novell.com/show_bug.cgi?id=889325
  service "workaround for races in initial db population" do
    service_name node[:neutron][:platform][:service_name]
    action [:start, :stop]
  end
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for neutron db_sync" do
  block do
    node.set[:neutron][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[neutron-db-manage migrate]", :immediately
end

# See comments for "neutron-db-manage migrate" above
execute "neutron-db-manage migrate fwaas" do
  user node[:neutron][:user]
  group node[:neutron][:group]
  command "neutron-db-manage --subproject neutron-fwaas upgrade head"
  only_if { !node[:neutron][:db_synced_fwaas] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

ruby_block "mark node for neutron db_sync fwaas" do
  block do
    node.set[:neutron][:db_synced_fwaas] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[neutron-db-manage migrate fwaas]", :immediately
end

if node[:neutron][:use_lbaas]
  # See comments for "neutron-db-manage migrate" above
  execute "neutron-db-manage migrate lbaas" do
    user node[:neutron][:user]
    group node[:neutron][:group]
    command "neutron-db-manage --subproject neutron-lbaas upgrade head"
    only_if { !node[:neutron][:db_synced_lbaas] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
  end

  ruby_block "mark node for neutron db_sync lbaas" do
    block do
      node.set[:neutron][:db_synced_lbaas] = true
      node.save
    end
    action :nothing
    subscribes :create, "execute[neutron-db-manage migrate lbaas]", :immediately
  end
end

if node[:neutron][:networking_plugin] == "ml2"
  if node[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2")
    # See comments for "neutron-db-manage migrate" above
    db_synced = node[:neutron][:db_synced_apic_ml2]
    is_founder = CrowbarPacemakerHelper.is_cluster_founder?(node)
    execute "apic-ml2-db-manage upgrade head" do
      user node[:neutron][:user]
      group node[:neutron][:group]
      command "apic-ml2-db-manage --config-dir /etc/neutron/neutron.conf.d \
                                  --config-file /etc/neutron/plugins/ml2/ml2_conf_cisco_apic.ini \
                                  upgrade head"
      only_if { !db_synced && (!ha_enabled || is_founder) }
    end

    ruby_block "mark node for apic-ml2-db-manage upgrade head" do
      block do
        node.set[:neutron][:db_synced_apic_ml2] = true
        node.save
      end
      action :nothing
      subscribes :create, "execute[apic-ml2-db-manage upgrade head]", :immediately
    end
  elsif node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp")
    # See comments for "neutron-db-manage migrate" above
    db_synced = node[:neutron][:db_synced_apic_gbp]
    is_founder = CrowbarPacemakerHelper.is_cluster_founder?(node)
    execute "gbp-db-manage upgrade head" do
      user node[:neutron][:user]
      group node[:neutron][:group]
      command "gbp-db-manage --config-dir /etc/neutron/neutron.conf.d \
                             --config-file /etc/neutron/plugins/ml2/ml2_conf_cisco_apic.ini \
                             upgrade head"
      only_if { !db_synced && (!ha_enabled || is_founder) }
    end

    ruby_block "mark node for gbp-db-manage upgrade head" do
      block do
        node.set[:neutron][:db_synced_apic_gbp] = true
        node.save
      end
      action :nothing
      subscribes :create, "execute[gbp-db-manage upgrade head]", :immediately
    end
  end
end

crowbar_pacemaker_sync_mark "create-neutron_db_sync" if ha_enabled

use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

service node[:neutron][:platform][:service_name] do
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:neutron][:config_file])
  if node[:neutron][:use_lbaas]
    subscribes :restart, resources(template: node[:neutron][:lbaas_config_file])
  end
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart node[:neutron][:platform][:service_name] do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

if node[:neutron][:use_infoblox]
  service node[:neutron][:platform][:infoblox_agent_name] do
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:neutron][:config_file])
    provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
  end
  utils_systemd_service_restart node[:neutron][:platform][:infoblox_agent_name] do
    action use_crowbar_pacemaker_service ? :disable : :enable
  end
end

include_recipe "neutron::api_register"

if ha_enabled
  log "HA support for neutron is enabled"
  include_recipe "neutron::server_ha"
else
  log "HA support for neutron is disabled"
end

# The post_install_conf recipe includes a few execute resources like this:
#
# execute "create_router" do
#   command "#{neutron_cmd} router-create router-floating"
#   not_if "out=$(#{neutron_cmd} router-list); ..."
#   action :nothing
# end
#
if node[:neutron][:create_default_networks]
  # If this runs simulatiously on multiple nodes (e.g. in a HA setup). It might
  # be that one node creates the router after the other did the "not_if" check.
  # In that case the router will be created twice (as it is perfectly fine to
  # have multiple routers with the same name). To avoid this race-condition we
  # make sure that the post_install_conf recipe is only executed on a single node
  # of the cluster.
  if !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)
    include_recipe "neutron::post_install_conf"
  end

  # All non-founder nodes should wait until the founder node is done
  # evaluating if the default networks need to be created, as this can
  # take a long time. Otherwise, the founder node will be delayed and
  # might produce pacemaker sync timeouts in other recipes where such
  # a big delay isn't expected (e.g. the network_agents recipe).
  crowbar_pacemaker_sync_mark "sync mark for neutron default networks" do
    mark "neutron_default_networks"
    action :sync
    timeout 180
    only_if { ha_enabled }
  end
end
