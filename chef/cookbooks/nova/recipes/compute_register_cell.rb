#
# Cookbook Name:: nova
# Recipe:: compute_register_cell
#
# Copyright 2018, SUSE Linux GmbH
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

return if node[:nova][:cellv2_discover_hosts_called]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

api_database_connection = fetch_database_connection_string(node[:nova][:api_db])

# create a tmp file with the api-database credentials, register the
# host and delete the creds
bash "nova-manage discover_hosts" do
  user node[:nova][:user]
  code <<-EOH
    tmpfile=$(mktemp /tmp/nova-discover-hosts.XXXXXX.conf)
    chmod 600 $tmpfile
    echo "[api_database]" >> $tmpfile
    echo "connection = #{api_database_connection}" >> $tmpfile
    nova-manage --config-file=$tmpfile cell_v2 discover_hosts --verbose
    rm -f "$tmpfile"
    EOH
end

# We want to keep a note that we've done discover_hosts, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual discover_hosts is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for cell_v2 discover_hosts" do
  block do
    node.set[:nova][:cellv2_discover_hosts_called] = true
    node.save
  end
end
