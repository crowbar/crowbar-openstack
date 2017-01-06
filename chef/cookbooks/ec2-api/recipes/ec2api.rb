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
# Cookbook Name:: ec2api
# Recipe:: ec2api

package "openstack-ec2-api"
package "openstack-ec2-api-api"
package "openstack-ec2-api-metadata"
package "openstack-ec2-api-s3"

# NOTE: ec2 is deployed via the nova barclamp
db_settings = fetch_database_settings "nova"

db_conn_scheme = db_settings[:url_scheme]

if db_settings[:backend_name] == "mysql"
  db_conn_scheme = "mysql+pymysql"
end

database_connection = "#{db_conn_scheme}://" \
  "#{node[:nova]["ec2-api"][:db][:user]}" \
  ":#{node[:nova]["ec2-api"][:db][:password]}" \
  "@#{db_settings[:address]}" \
  "/#{node[:nova]["ec2-api"][:db][:database]}"

# Create the ec2 Database
database "create #{node[:nova]["ec2-api"][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:nova]["ec2-api"][:db][:database]
  provider db_settings[:provider]
  action :create
end

database_user "create #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:nova]["ec2-api"][:db][:database]
  username node[:nova]["ec2-api"][:db][:user]
  password node[:nova]["ec2-api"][:db][:password]
  host "%"
  provider db_settings[:user_provider]
  action :create
end

database_user "grant database access for #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:nova]["ec2-api"][:db][:database]
  username node[:nova]["ec2-api"][:db][:user]
  password node[:nova]["ec2-api"][:db][:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
end

rabbit_settings = fetch_rabbitmq_settings "nova"
keystone_settings = KeystoneHelper.keystone_settings(node, "nova")

template node[:nova]["ec2-api"][:config_file] do
  source "ec2api.conf.erb"
  owner "root"
  group node[:nova]["ec2-api"][:group]
  mode 0o640
  variables(
    debug: node[:nova][:debug],
    verbose: node[:nova][:verbose],
    database_connection: database_connection,
    rabbit_settings: rabbit_settings,
    keystone_settings: keystone_settings,
  )
end

node.save

service "openstack-ec2-api-api" do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:nova]["ec2-api"][:config_file])
end

service "openstack-ec2-api-metadata" do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:nova]["ec2-api"][:config_file])
end

service "openstack-ec2-api-s3" do
  action [:enable, :start]
  subscribes :restart, resources(template: node[:nova]["ec2-api"][:config_file])
end
