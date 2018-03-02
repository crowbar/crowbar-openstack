# Copyright 2017 SUSE Linux GmbH
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

package "openstack-murano"

db_settings = fetch_database_settings
network_settings = MuranoHelper.network_settings(node)

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# get Database data
db_password = node[:murano][:db][:password]
sql_connection = "#{db_settings[:url_scheme]}://#{node[:murano][:db][:user]}:"\
                 "#{db_password}@#{db_settings[:address]}/"\
                 "#{node[:murano][:db][:database]}"

# neutron insecure?
neutron = get_instance("roles:neutron-server")
neutron_insecure = neutron[:neutron][:ssl][:insecure]

template "/etc/murano/murano.conf" do
  source "murano.conf.erb"
  owner "root"
  group node[:murano][:group]
  mode "0640"
  variables(
    bind_host: network_settings[:api][:bind_host],
    bind_port: network_settings[:api][:bind_port],
    sql_connection: sql_connection,
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, :murano),
    neutron_insecure: neutron_insecure
  )
end

node.save
