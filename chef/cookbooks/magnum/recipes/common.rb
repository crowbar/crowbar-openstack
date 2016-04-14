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

package "openstack-magnum"

db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
db_password = ""
if node.roles.include? "magnum-server"
  db_password = node[:magnum][:db][:password]
else
  # pickup password to database from magnum-server node
  node_servers = search(:node, "roles:magnum-server") || []
  if node_servers.length > 0
    db_password = node_servers[0][:magnum][:db][:password]
  end
end
sql_connection = "#{db_settings[:url_scheme]}://#{node[:magnum][:db][:user]}:"\
                 "#{db_password}@#{db_settings[:address]}/"\
                 "#{node[:magnum][:db][:database]}"

# address/port binding
my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(
  node, "admin").address
node.set[:magnum][:my_ip] = my_ipaddress
node.set[:magnum][:api][:bind_host] = my_ipaddress

if node[:magnum][:ha][:enabled]
  bind_port = node[:magnum][:ha][:ports][:api]
else
  if node[:magnum][:api][:bind_open_address]
    bind_host = "0.0.0.0"
  else
    bind_host = node[:magnum][:api][:bind_host]
  end
  bind_port = node[:magnum][:api][:bind_port]
end


template "/etc/magnum/magnum.conf" do
  source "magnum.conf.erb"
  owner "root"
  group node[:magnum][:group]
  mode 0640
  variables(
    bind_host: bind_host,
    bind_port: bind_port,
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :magnum),
  )
end

node.save
