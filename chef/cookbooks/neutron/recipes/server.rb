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

unless node[:neutron][:use_gitrepo]
  pkgs = node[:neutron][:platform][:pkgs]
  pkgs.each { |p| package p }
else
  neutron_path = "/opt/neutron"
  venv_path = node[:neutron][:use_virtualenv] ? "#{neutron_path}/.venv" : nil

  link_service "neutron-server" do
    virtualenv venv_path
    bin_name "neutron-server --config-dir /etc/neutron/"
  end
end


include_recipe "neutron::database"
include_recipe "neutron::common_config"


if node[:neutron][:use_ml2] && node[:neutron][:networking_plugin] != "vmware"
  plugin_cfg_path = "/etc/neutron/plugins/ml2/ml2_conf.ini"
else
  case node[:neutron][:networking_plugin]
  when "openvswitch", "cisco"
    agent_config_path = "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"
  when "linuxbridge"
    agent_config_path = "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
  when "vmware"
    agent_config_path = "/etc/neutron/plugins/nicira/nvp.ini"
  end

  plugin_cfg_path = agent_config_path
end

template "/etc/sysconfig/neutron" do
  source "sysconfig.neutron.erb"
  owner "root"
  group "root"
  mode 0640
  # whenever changing plugin_config_file here, keep in mind to change the call
  # to neutron-db-manage too
  if node[:neutron][:networking_plugin] == "cisco" and node[:neutron][:use_ml2]
    variables(
      :plugin_config_file => plugin_cfg_path +  " /etc/neutron/plugins/ml2/ml2_conf_cisco.ini"
    )
  else
    variables(
      :plugin_config_file => plugin_cfg_path
    )
  end
  only_if { node[:platform] == "suse" }
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end

file "/etc/default/neutron-server" do
  action :delete
  not_if { node[:platform] == "suse" }
  notifies :restart, "service[#{node[:neutron][:platform][:service_name]}]"
end


vlan_start = node[:network][:networks][:nova_fixed][:vlan]
num_vlans = node[:neutron][:num_vlans]
vlan_end = [vlan_start + num_vlans - 1, 4094].min

if node[:neutron][:networking_plugin] == "cisco"
  mechanism_driver = "openvswitch,cisco_nexus"
else
  mechanism_driver = node[:neutron][:networking_plugin]
end

template plugin_cfg_path do
  source "ml2_conf.ini.erb"
  owner node[:neutron][:platform][:user]
  group "root"
  mode "0640"
  variables(
    :networking_mode => node[:neutron][:networking_mode],
    :mechanism_driver => mechanism_driver,
    :vlan_start => vlan_start,
    :vlan_end => vlan_end
  )
  only_if { node[:neutron][:use_ml2] && node[:neutron][:networking_plugin] != "vmware" }
end


if node[:neutron][:networking_plugin] == "cisco"
  include_recipe "neutron::cisco_support"
end

ha_enabled = node[:neutron][:ha][:server][:enabled]

# There's no way to do DB migration for neutron: it's automatically done on
# startup. This is fine in general, except for HA where we want this to happen
# once before we start the daemon through pacemaker (otherwise, with the clone,
# it will start on several servers concurrently, and the resource will fail on
# all but one, defeating HA by default). For this reason, we manually start the
# daemon once to do the migration if we use HA.
if ha_enabled
  crowbar_pacemaker_sync_mark "wait-neutron_db_sync"

  service "initial neutron start for db sync" do
    if node[:neutron][:use_gitrepo]
      service_name "neutron-server"
    else
      service_name node[:neutron][:platform][:service_name]
    end
    action [:start, :stop]
    # We only do the hack the first time; note that the only_if constraint will
    # apply for both :start and :stop, which means that we can't change the
    # db_synced attribute in a notification (as we do for other cookbooks): if
    # we do so, :stop will not be called (as the attribute will have been
    # set)
    only_if { !node[:neutron][:db_synced] && CrowbarPacemakerHelper.is_cluster_founder?(node) }
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
    only_if { !node[:neutron][:db_synced] && CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-neutron_db_sync"
end

service node[:neutron][:platform][:service_name] do
  service_name "neutron-server" if node[:neutron][:use_gitrepo]
  supports :status => true, :restart => true
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
