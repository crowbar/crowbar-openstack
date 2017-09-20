#
# Copyright 2016 SUSE Linux GmbH
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
# Cookbook Name:: magnum
# Recipe:: sql
#

ha_enabled = node[:magnum][:ha][:enabled]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-magnum_database" if ha_enabled

is_cluster_founder = CrowbarPacemakerHelper.is_cluster_founder?(node)
# Create the Magnum Database
database "create #{node[:magnum][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:magnum][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || is_cluster_founder }
end

database_user "create magnum database user" do
  host "%"
  connection db_settings[:connection]
  username node[:magnum][:db][:user]
  password node[:magnum][:db][:password]
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || is_cluster_founder }
end

database_user "grant database access for magnum database user" do
  connection db_settings[:connection]
  username node[:magnum][:db][:user]
  password node[:magnum][:db][:password]
  database_name node[:magnum][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || is_cluster_founder }
end

is_cluster_founder = CrowbarPacemakerHelper.is_cluster_founder?(node)
is_db_synced = node[:magnum][:db_synced]

execute "magnum-manage db sync" do
  command "magnum-db-manage upgrade"
  user node[:magnum][:user]
  group node[:magnum][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !is_db_synced && (!ha_enabled || is_cluster_founder) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for magnum db_sync" do
  block do
    node.set[:magnum][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[magnum-manage db sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-magnum_database" if ha_enabled
