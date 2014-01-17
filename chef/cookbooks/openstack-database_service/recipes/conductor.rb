#
# Cookbook Name:: openstack-database_service
# Recipe:: conductor
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

platform_options = node["openstack"]["database_service"]["platform"]

platform_options["conductor_packages"].each do |pkg|
  package pkg
end

service "trove-conductor" do
  service_name platform_options["conductor_service"]
  supports :status => true, :restart => true

  action [ :enable ]
end

db_user = node["openstack"]["database_service"]["db"]["username"]
db_pass = db_password "trove"
db_uri = db_uri("database_service", db_user, db_pass).to_s
identity_uri = endpoint("identity-api")

template "/etc/trove/trove-conductor.conf" do
  source "trove-conductor.conf.erb"
  owner node["openstack"]["database_service"]["user"]
  group node["openstack"]["database_service"]["group"]
  mode 00640
  variables(
    :database_connection => db_uri,
    :identity_uri => identity_uri
    )

  notifies :restart, "service[trove-conductor]", :immediately
end

