#
# Cookbook Name:: openstack-database_service
# Recipe:: api
#
# Copyright 2013, SUSE Linux GmbH
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

class ::Chef::Recipe
  include ::Openstack
end

if node["openstack"]["database_service"]["syslog"]["use"]
  include_recipe "openstack-common::logging"
end

platform_options = node["openstack"]["database_service"]["platform"]

platform_options["api_packages"].each do |pkg|
  package pkg
end

service "trove-api" do
  service_name platform_options["api_service"]
  supports :status => true, :restart => true

  action [ :enable ]
end

db_user = node["openstack"]["database_service"]["db"]["username"]
db_pass = db_password "openstack-database_service"
db_uri = db_uri("database_service", db_user, db_pass).to_s

api_endpoint = endpoint "database_service-api"

identity_uri = endpoint("identity-api")
compute_uri = endpoint("compute-api").to_s.gsub(/%\(tenant_id\)s/, "")
block_storage_uri = endpoint("volume-api").to_s.gsub(/%\(tenant_id\)s/, "")
object_storage_uri = endpoint("object-storage-api")

rabbit_pass = user_password node["openstack"]["database_service"]["rabbit"]["username"]

template "/etc/trove/trove.conf" do
  source "trove.conf.erb"
  owner node["openstack"]["database_service"]["user"]
  group node["openstack"]["database_service"]["group"]
  mode 00640
  variables(
    :database_connection => db_uri,
    :endpoint => api_endpoint,
    :rabbit_pass => rabbit_pass,
    :identity_uri => identity_uri,
    :compute_uri => compute_uri,
    :block_storage_uri => block_storage_uri,
    :object_storage_uri => object_storage_uri
    )

  notifies :restart, "service[trove-api]", :immediately
end

admin_token = secret "secrets", "openstack_identity_bootstrap_token"
identity_admin_uri = endpoint("identity-admin")

template "/etc/trove/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node["openstack"]["database_service"]["user"]
  group node["openstack"]["database_service"]["group"]
  mode 00640
  variables(
    :identity_admin_uri => identity_admin_uri,
    :admin_token => admin_token
    )

  notifies :restart, "service[trove-api]", :immediately
end

execute "trove-manage --config-file=/etc/trove/trove.conf db_wipe #{node["openstack"]["db"]["database_service"]["db_type"]}" do
  notifies :restart, "service[trove-api]", :immediately
end
