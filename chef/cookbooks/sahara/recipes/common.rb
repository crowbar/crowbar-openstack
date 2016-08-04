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

package "openstack-sahara"

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
db_password = node[:sahara][:db][:password]
sql_connection = "#{db_settings[:url_scheme]}://#{node[:sahara][:db][:user]}:"\
                 "#{db_password}@#{db_settings[:address]}/"\
                 "#{node[:sahara][:db][:database]}"

# address/port binding
my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(
  node, "admin").address
node.set[:sahara][:api][:bind_host] = my_ipaddress

# TODO : Handle HA condition
bind_port = node[:sahara][:api][:bind_port]
bind_host = node[:sahara][:api][:bind_host]
bind_host = "0.0.0.0" if node[:sahara][:api][:bind_open_address]

template "/etc/sahara/sahara.conf" do
  source "sahara.conf.erb"
  owner "root"
  group node[:sahara][:group]
  mode 0640
  variables(
    trustee: node[:sahara][:trustee],
    bind_host: bind_host,
    bind_port: bind_port,
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :sahara),
  )
end

node.save
