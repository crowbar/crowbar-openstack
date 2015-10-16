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

pkgs = node[:neutron][:platform][:pkgs] + node[:neutron][:platform][:pkgs_fwaas]
pkgs += node[:neutron][:platform][:pkgs_lbaas] if node[:neutron][:use_lbaas]
pkgs.each { |p| package p }

include_recipe "neutron::database"

if node[:neutron][:api][:protocol] == "https"
  if node[:neutron][:ssl][:generate_certs]
    package "openssl"
    ruby_block "generate_certs for neutron" do
      block do
        unless ::File.exists? node[:neutron][:ssl][:certfile] and ::File.exists? node[:neutron][:ssl][:keyfile]
          require "fileutils"

          Chef::Log.info("Generating SSL certificate for neutron...")

          [:certfile, :keyfile].each do |k|
            dir = File.dirname(node[:neutron][:ssl][k])
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
          end

          # Generate private key
          %x(openssl genrsa -out #{node[:neutron][:ssl][:keyfile]} 4096)
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", node[:neutron][:group], node[:neutron][:ssl][:keyfile]
          FileUtils.chmod 0640, node[:neutron][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname node[:neutron][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{node[:fqdn]}\""
          %x(openssl req -new -key #{node[:neutron][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject})
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          %x(openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{node[:neutron][:ssl][:keyfile]} -out #{node[:neutron][:ssl][:certfile]})
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
    unless ::File.exists? node[:neutron][:ssl][:certfile]
      message = "Certificate \"#{node[:neutron][:ssl][:certfile]}\" is not present."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if node[:neutron][:ssl][:cert_required] and !::File.exists? node[:neutron][:ssl][:ca_certs]
    message = "Certificate CA \"#{node[:neutron][:ssl][:ca_certs]}\" is not present."
    Chef::Log.fatal(message)
    raise message
  end
end

include_recipe "neutron::common_config"

if node[:neutron][:networking_plugin] == "vmware"
  plugin_cfg_path = "/etc/neutron/plugins/vmware/nsx.ini"
else
  plugin_cfg_path = "/etc/neutron/plugins/ml2/ml2_conf.ini"
end

template "/etc/sysconfig/neutron" do
  source "sysconfig.neutron.erb"
  owner "root"
  group "root"
  mode 0640
  # whenever changing plugin_config_file here, keep in mind to change the call
  # to neutron-db-manage too
  if node[:neutron][:networking_plugin] == "ml2" and node[:neutron][:ml2_mechanism_drivers].include?("cisco_nexus")
    variables(
      plugin_config_file: plugin_cfg_path +  " /etc/neutron/plugins/ml2/ml2_conf_cisco.ini"
    )
  else
    variables(
      plugin_config_file: plugin_cfg_path
    )
  end
  only_if { node[:platform_family] == "suse" }
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

template "/etc/default/neutron-server" do
  source "neutron-server.erb"
  owner "root"
  group node[:neutron][:platform][:group]
  variables(
      neutron_plugin_config: "/etc/neutron/plugins/ml2/ml2_conf.ini"
    )
  only_if { node[:platform_family] == "debian" }
end

directory "/var/cache/neutron" do
  owner node[:neutron][:user]
  group node[:neutron][:group]
  mode 0755
  action :create
  only_if { node[:platform_family] == "debian" }
end

vlan_start = node[:network][:networks][:nova_fixed][:vlan]
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

external_networks = ["floating"]
external_networks.concat(node[:neutron][:additional_external_networks])

case node[:neutron][:networking_plugin]
when "ml2"
  ml2_type_drivers = node[:neutron][:ml2_type_drivers]
  #TODO(vuntz): temporarily disable the hyperv mechanism since we're lacking networking-hyperv from stackforge
  #ml2_mechanism_drivers = node[:neutron][:ml2_mechanism_drivers].dup.push("hyperv")
  ml2_mechanism_drivers = node[:neutron][:ml2_mechanism_drivers].dup
  if node[:neutron][:use_l2pop] && (ml2_type_drivers.include?("gre") || ml2_type_drivers.include?("vxlan"))
    ml2_mechanism_drivers.push("l2population")
  end

  template plugin_cfg_path do
    source "ml2_conf.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      ml2_mechanism_drivers: ml2_mechanism_drivers,
      ml2_type_drivers: node[:neutron][:ml2_type_drivers],
      tenant_network_types: tenant_network_types,
      vlan_start: vlan_start,
      vlan_end: vlan_end,
      gre_start: gre_start,
      gre_end: gre_end,
      vxlan_start: vni_start,
      vxlan_end: vni_end,
      vxlan_mcast_group: node[:neutron][:vxlan][:multicast_group],
      external_networks: external_networks
    )
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

  template plugin_cfg_path do
    cookbook "neutron"
    source "nsx.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      vmware_config: node[:neutron][:vmware]
    )
  end
end

if node[:neutron][:networking_plugin] == "ml2" and node[:neutron][:ml2_mechanism_drivers].include?("cisco_nexus")
  include_recipe "neutron::cisco_support"
end

ha_enabled = node[:neutron][:ha][:server][:enabled]

crowbar_pacemaker_sync_mark "wait-neutron_db_sync"

execute "neutron-db-manage migrate" do
  user node[:neutron][:user]
  group node[:neutron][:group]
  case node[:platform_family]
  when "suse"
    command 'source /etc/sysconfig/neutron; \
             for i in $NEUTRON_PLUGIN_CONF; do \
               CONF_ARGS="$CONF_ARGS --config-file $i"; \
             done; \
             neutron-db-manage --config-file /etc/neutron/neutron.conf $CONF_ARGS upgrade head'
  when "debian"
    command 'source /etc/default/neutron-server; \
             neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file $NEUTRON_PLUGIN_CONFIG upgrade head'
  else
    command "neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head"
  end
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
    node[:neutron][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[neutron-db-manage migrate]", :immediately
end

# See comments for "neutron-db-manage migrate" above
execute "neutron-db-manage migrate fwaas" do
  user node[:neutron][:user]
  group node[:neutron][:group]
  command "neutron-db-manage --service fwaas upgrade head"
  only_if { !node[:neutron][:db_synced_fwaas] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

ruby_block "mark node for neutron db_sync fwaas" do
  block do
    node[:neutron][:db_synced_fwaas] = true
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
    command "neutron-db-manage --service lbaas upgrade head"
    only_if { !node[:neutron][:db_synced_lbaas] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
  end

  ruby_block "mark node for neutron db_sync lbaas" do
    block do
      node[:neutron][:db_synced_lbaas] = true
      node.save
    end
    action :nothing
    subscribes :create, "execute[neutron-db-manage migrate lbaas]", :immediately
  end
end

crowbar_pacemaker_sync_mark "create-neutron_db_sync"

service node[:neutron][:platform][:service_name] do
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, resources("template[#{plugin_cfg_path}]")
  subscribes :restart, resources("template[/etc/neutron/neutron.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
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
# If this runs simulatiously on multiple nodes (e.g. in a HA setup). It might
# be that one node creates the router after the other did the "not_if" check.
# In that case the router will be created twice (as it is perfectly fine to
# have multiple routers with the same name). To avoid this race-condition we
# make sure that the post_install_conf recipe is only executed on a single node
# of the cluster.
if !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)
  include_recipe "neutron::post_install_conf"
end

node[:neutron][:monitor] = {} if node[:neutron][:monitor].nil?
node[:neutron][:monitor][:svcs] = [] if node[:neutron][:monitor][:svcs].nil?
node[:neutron][:monitor][:svcs] << ["neutron"] if node[:neutron][:monitor][:svcs].empty?
node.save
