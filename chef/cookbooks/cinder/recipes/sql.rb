#
# Cookbook Name:: cinder
# Recipe:: sql
#
# Copyright 2010-2011, Opscode, Inc.
# Copyright 2011, Dell, Inc.
# Copyright 2012, Dell, Inc.
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

ha_enabled = node[:cinder][:ha][:enabled]

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-cinder_database" if ha_enabled

# Create the Cinder Database
database "create #{node[:cinder][:db][:database]} database" do
    connection db_settings[:connection]
    database_name node[:cinder][:db][:database]
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create cinder database user" do
    host "%"
    connection db_settings[:connection]
    username node[:cinder][:db][:user]
    password node[:cinder][:db][:password]
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for cinder database user" do
    connection db_settings[:connection]
    username node[:cinder][:db][:user]
    password node[:cinder][:db][:password]
    database_name node[:cinder][:db][:database]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    require_ssl db_settings[:connection][:ssl][:enabled]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Some live migrations need to happen before revision 97, so we first need to
# sync all revisions up to 96
execute "cinder-manage db sync up to revision 96" do
  command "cinder-manage db sync 96"
  user node[:cinder][:user]
  group node[:cinder][:group]
  ignore_failure true
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    !node[:cinder][:db_synced] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) &&
      (`cinder-manage --log-file /dev/null db version`.to_i < 97)
  end
end

# Now we can run the live migrations
execute "cinder-manage db online_data_migrations" do
  user node[:cinder][:user]
  group node[:cinder][:group]
  command "cinder-manage db online_data_migrations"
  ignore_failure true
  action :run
  only_if do
    !node[:cinder][:db_synced] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) &&
      (`cinder-manage --log-file /dev/null db version`.to_i == 96)
  end
end

# update to the last cinder db revision
execute "cinder-manage db sync" do
  command "cinder-manage db sync"
  user node[:cinder][:user]
  group node[:cinder][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:cinder][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for cinder db_sync" do
  block do
    node.set[:cinder][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[cinder-manage db sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-cinder_database" if ha_enabled
