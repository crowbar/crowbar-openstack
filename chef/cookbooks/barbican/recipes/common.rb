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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"

package "openstack-barbican"

db_settings = fetch_database_settings

db_conn_scheme = db_settings[:url_scheme]

public_host = CrowbarHelper.get_host_for_public_url(node, false, false)

barbican_protocol = node[:barbican][:api][:ssl] ? "https" : "http"

if db_settings[:backend_name] == "mysql"
  db_conn_scheme = "mysql+pymysql"
end

database_connection = "#{db_conn_scheme}://" \
  "#{node[:barbican][:db][:user]}" \
  ":#{node[:barbican][:db][:password]}" \
  "@#{db_settings[:address]}" \
  "/#{node[:barbican][:db][:database]}"

# Create the Barbican Database
database "create #{node[:barbican][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:barbican][:db][:database]
  provider db_settings[:provider]
  action :create
end

database_user "create #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:barbican][:db][:database]
  username node[:barbican][:db][:user]
  password node[:barbican][:db][:password]
  host "%"
  provider db_settings[:user_provider]
  action :create
end

database_user "grant database access for #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:barbican][:db][:database]
  username node[:barbican][:db][:user]
  password node[:barbican][:db][:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
end

template "/etc/barbican/barbican.conf" do
  source "barbican.conf.erb"
  owner "root"
  group node[:barbican][:group]
  mode 0640
  variables(
    database_connection: database_connection,
    kek: node[:barbican][:kek],
    keystone_listener: node[:barbican][:enable_keystone_listener],
    host_href: "#{barbican_protocol}://#{public_host}:#{node[:barbican][:api][:bind_port]}",
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, @cookbook_name),
  )
  notifies :reload, resources(service: "apache2")
end

node.save
