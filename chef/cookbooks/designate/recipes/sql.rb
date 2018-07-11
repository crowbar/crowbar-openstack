# Copyright 2018 SUSE Linux GmbH
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
# Cookbook Name:: designate
# Recipe:: sql
#

ha_enabled = node[:designate][:ha][:enabled]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-designate_database" if ha_enabled

# Create the designate Database
database "create #{node[:designate][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:designate][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create designate database user" do
  host "%"
  connection db_settings[:connection]
  username node[:designate][:db][:user]
  password node[:designate][:db][:password]
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for designate database user" do
  connection db_settings[:connection]
  username node[:designate][:db][:user]
  password node[:designate][:db][:password]
  database_name node[:designate][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

execute "designate-manage database sync" do
  command "designate-manage database sync"
  user node[:designate][:user]
  group node[:designate][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    !node[:designate][:db_synced] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for designate-manage database sync" do
  block do
    node.set[:designate][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[designate-manage database sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-designate_database" if ha_enabled
