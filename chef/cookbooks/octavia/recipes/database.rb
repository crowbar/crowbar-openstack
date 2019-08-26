# Copyright 2019 SUSE Linux GmbH.
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

ha_enabled = node[:octavia][:ha][:enabled]

db_settings = fetch_database_settings
crowbar_pacemaker_sync_mark "wait-octavia_database" if ha_enabled

db_user = node[:octavia][:db][:user]
db_pass = node[:octavia][:db][:password]
db_name = node[:octavia][:db][:database]

# Create the Octavia Database

database "create #{db_name} octavia database" do
  connection db_settings[:connection]
  database_name db_name
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create #{db_user} user in #{db_name} octavia database" do
  connection db_settings[:connection]
  username db_user
  password db_pass
  host "%"
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for #{db_user} user in #{db_name} octavia database" do
  connection db_settings[:connection]
  username db_user
  password db_pass
  database_name db_name
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

execute "create database initial content" do
  command "octavia-db-manage upgrade head"
  only_if do
    !node[:octavia][:db_synced] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
  retries 5
  retry_delay 10
  action :run
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for octavia db_sync" do
  block do
    node.set[:octavia][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[create database initial content]", :immediately
end

crowbar_pacemaker_sync_mark "create-octavia_database" if ha_enabled
