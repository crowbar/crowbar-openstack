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

crowbar_pacemaker_sync_mark "wait-nova_database" do
  # the db sync is very slow for nova
  timeout 120
end

[node[:nova][:db], node[:nova][:api_db]].each do |d|
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

# if we're upgrading from juno, we first need to upgrade to the kilo state,
# then run nova-manage db migrate_flavor_data and after that, run the rest
# of the db migrations.
db_version_cmd = "nova-manage db version"
last_juno_migration = 254
last_kilo_migration = 290

execute "nova-manage db sync (kilo migrations)" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db sync --version #{last_kilo_migration}"
  action :run
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    if !node[:nova][:db_synced] &&
        (!node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
      cmd = Mixlib::ShellOut.new(db_version_cmd,
                                 user: node[:nova][:user],
                                 group: node[:nova][:group])
      cmd.run_command
      db_version = cmd.stdout.to_i
      if db_version >= last_juno_migration && db_version < last_kilo_migration
        true
      else
        false
      end
    else
      false
    end
  end
  notifies :run, "execute[nova-manage db migrate_flavor_data]", :immediately
end

# now run the db migrate_flavor tool if needed
execute "nova-manage db migrate_flavor_data" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db migrate_flavor_data --force"
  # We only run this step on explicit notification of the previous
  # "db sync (kilo migrations)" step to avoid another complex "only_if"
  # condition.
  action :nothing
end

# and finally the rest of the migrations
execute "nova-manage db sync" do
  user node[:nova][:user]
  group node[:nova][:group]
  command "nova-manage db sync"
  action :run
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
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

# and finally the rest of the migrations
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

crowbar_pacemaker_sync_mark "create-nova_database"

# save data so it can be found by search
node.save
