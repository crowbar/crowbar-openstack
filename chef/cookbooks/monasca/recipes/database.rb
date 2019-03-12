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

monasca_servers = search(:node, "roles:monasca-server")
monasca_monitoring_host =
  Chef::Recipe::Barclamp::Inventory.get_network_by_type(
    monasca_servers[0], node[:monasca][:network]).address

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

tsdb = node["monasca"]["tsdb"]

# create influx Database for monasca time series
ruby_block "Create influx database \"#{node['monasca']['db_monapi']['database']}\"" do
  block do
    InfluxDBHelper.create_database(node["monasca"]["db_monapi"]["database"],
                                   influx_host: monasca_monitoring_host)
  end
  retries 5
  only_if { tsdb == "influxdb" }
end

# Set retention policy for auto-generated (called "autogen") policy
ruby_block "Set retention policy for influx database \"#{node['monasca']['db_monapi']['database']}\"" do
  block do
    InfluxDBHelper.set_retention_policy(node["monasca"]["db_monapi"]["database"], "autogen",
                                        node["monasca"]["master"]["influxdb_retention_policy"], 1,
                                        influx_host: monasca_monitoring_host)
  end
  only_if { tsdb == "influxdb" }
end

crowbar_pacemaker_sync_mark "create-monasca_database" if ha_enabled
