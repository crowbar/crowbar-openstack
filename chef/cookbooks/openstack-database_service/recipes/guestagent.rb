#
# Cookbook Name:: openstack-database-service
# Recipe:: guestagent
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

platform_options = node["openstack"]["database-service"]["platform"]

platform_options["guestagent_packages"].each do |pkg|
  package pkg
end

service "trove-guestagent" do
  service_name platform_options["guestagent_service"]
  supports :status => true, :restart => true

  action [ :enable ]
end

api_endpoint = endpoint("database-service-guestagent")

db_user = node["openstack"]["database-service"]["db"]["username"]
db_pass = get_password 'db', "trove"
db_uri = db_uri("database-service", db_user, db_pass).to_s

identity_uri = endpoint("identity-api")
object_storage_uri = endpoint("object-storage-api")

rabbit_pass = get_password(
  'user', node['openstack']['mq']['database-service']['rabbit']['userid'])

template "/etc/trove/trove-guestagent.conf" do
  source "trove-guestagent.conf.erb"
  owner node["openstack"]["database-service"]["user"]
  group node["openstack"]["database-service"]["group"]
  mode 00640
  variables(
    :database_connection => db_uri,
    :rabbit_pass => rabbit_pass,
    :endpoint => api_endpoint,
    :identity_uri => identity_uri,
    :object_storage_uri => object_storage_uri
    )

  notifies :restart, "service[trove-guestagent]", :immediately
end
