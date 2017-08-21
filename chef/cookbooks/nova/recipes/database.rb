#
# Cookbook Name:: nova
# Recipe:: database
#
# Copyright 2010-2011, Opscode, Inc.
# Copyright 2011, Dell, Inc.
# Copyright 2012, SUSE Linux Products GmbH.
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

include_recipe "database::client"

ha_enabled = node[:nova][:ha][:enabled]

db_settings = fetch_database_settings

# Wait for all nodes to reach this point so we avoid any timeouts due to the
# non-founders being faster than the founder and not syncing properly with it
crowbar_pacemaker_sync_mark "sync-nova_before_database" if ha_enabled

crowbar_pacemaker_sync_mark "wait-nova_database" do
  # the db sync is very slow for nova
  timeout 120
  only_if { ha_enabled }
end

[node[:nova][:db], node[:nova][:api_db], node[:nova][:placement_db]].each do |d|
  # Creates empty nova database
  database "create #{d[:database]} database" do
    connection db_settings[:connection]
    database_name d[:database]
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "create #{d[:user]} database user" do
    connection db_settings[:connection]
    username d[:user]
    password d[:password]
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "grant privileges to the #{d[:user]} database user" do
    connection db_settings[:connection]
    database_name d[:database]
    username d[:user]
    password d[:password]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

# create the nova_cell0 database (similar to nova_api) and give the
# nova DB user the correct privileges
database "create nova_cell0 database" do
  connection db_settings[:connection]
  database_name "nova_cell0"
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant privileges to the #{node[:nova][:db][:user]} database user" do
  connection db_settings[:connection]
  database_name "nova_cell0"
  username node[:nova][:db][:user]
  password node[:nova][:db][:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end


execute "nova-manage api_db sync" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage api_db sync"
  action :run
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    !node[:nova][:api_db_synced] &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# handle cell0 and cell1 before doing the db sync
execute "nova-manage create cell0" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage cell_v2 map_cell0"
  action :run
  # TODO: Does not work on Newton (14.x.x). Remove when switched to Ocata
  not_if 'rpm -qa --qf "%{VERSION}\n" openstack-nova|grep ^14\.'
  only_if do
    !node[:nova][:db_synced] &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

execute "nova-manage create cell1" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage cell_v2 create_cell --name cell1 --verbose"
  action :run
  # TODO: Does not work on Newton (14.x.x). Remove when switched to Ocata
  not_if 'rpm -qa --qf "%{VERSION}\n" openstack-nova|grep ^14\.'
  only_if do
    !node[:nova][:db_synced] &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

execute "nova-manage db sync up to revision 329" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db sync --version 329"
  action :run
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    !node[:nova][:db_synced] && (`nova-manage db version`.to_i < 329) &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# Perform online migrations up to revision 329 (the ones for later revisions
# will fail. These errors can probably be ignored (hence the ignore_failure usage)
execute "nova-manage db online_data_migrations" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db online_data_migrations"
  ignore_failure true
  action :run
  only_if do
    !node[:nova][:db_synced] && (`nova-manage db version`.to_i == 329) &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# Update Nova DB to latest revision
execute "nova-manage db sync" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db sync"
  action :run
  only_if do
    !node[:nova][:db_synced] &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# Run online migration again to cover the ones that failed in the first pass.
execute "nova-manage db online_data_migrations (continue)" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db online_data_migrations"
  action :run
  only_if do
    !node[:nova][:db_synced] &&
      (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for nova db_sync" do
  block do
    node.set[:nova][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[nova-manage db sync]", :immediately
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for nova api_db_sync" do
  block do
    node.set[:nova][:api_db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[nova-manage api_db sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-nova_database" if ha_enabled
