# Copyright 2013 Dell, Inc.
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

dirty = false

ha_enabled = node[:neutron][:ha][:server][:enabled]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

props = [{"db_name" => node[:neutron][:db][:database],
          "db_user" => node[:neutron][:db][:user],
          "db_pass" => node[:neutron][:db][:password],
          "db_conn_name" => "sql_connection"  }
        ]

crowbar_pacemaker_sync_mark "wait-neutron_database" if ha_enabled

# Create the Neutron Databases
props.each do |prop|
  db_name = prop["db_name"]
  db_user = prop["db_user"]
  db_pass = prop["db_pass"]
  db_conn_name = prop["db_conn_name"]

  database "create #{db_name} neutron database" do
    connection db_settings[:connection]
    database_name "#{db_name}"
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "create #{db_user} user in #{db_name} neutron database" do
    connection db_settings[:connection]
    username "#{db_user}"
    password "#{db_pass}"
    host "%"
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "grant database access for #{db_user} user in #{db_name} neutron database" do
    connection db_settings[:connection]
    username "#{db_user}"
    password "#{db_pass}"
    database_name "#{db_name}"
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    require_ssl db_settings[:connection][:ssl][:enabled]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  db_address = fetch_database_connection_string(node[:neutron][:db])
  if node[@cookbook_name][:db][db_conn_name] != db_address
    node.set[@cookbook_name][:db][db_conn_name] = db_address
    dirty = true
  end
end

crowbar_pacemaker_sync_mark "create-neutron_database" if ha_enabled

node.save if dirty
