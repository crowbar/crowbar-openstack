#
# Cookbook Name:: monasca
# Recipe:: database
#
# Copyright 2018, SUSE Linux GmbH.
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

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"

ha_enabled = node[:monasca][:ha][:enabled]

crowbar_pacemaker_sync_mark "wait-monasca_database"

[node[:monasca][:db_monapi], node[:monasca][:db_grafana]].each do |d|
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
    host "%"
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
    require_ssl db_settings[:connection][:ssl][:enabled]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

# FIXME(toabctl):the package contains the mon_mysql.sql file
# would be good if the file is in a extra package
package "openstack-monasca-api"

execute "apply mon database schema migration" do
  command "/usr/bin/mysql --no-defaults -u #{node[:monasca][:db_monapi][:user]} -p#{node[:monasca][:db_monapi][:password]} -h #{db_settings[:connection][:host]} #{node[:monasca][:db_monapi][:database]} < /usr/share/monasca-api/schema/mon_mysql.sql"
  action :run
  only_if do
    !node[:monasca][:db_monapi_synced] &&
      (!node[:monasca][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# We want to keep a note that we've done the schema apply,
# so we don't do it again.
ruby_block "mark node for monasca mon db schema migration" do
  block do
    node.set[:monasca][:db_monapi_synced] = true
    node.save
  end
  not_if { node[:monasca][:db_monapi_synced] }
end

crowbar_pacemaker_sync_mark "create-monasca_database" if ha_enabled
