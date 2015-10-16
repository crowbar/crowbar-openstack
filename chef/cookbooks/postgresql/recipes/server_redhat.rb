#
# Cookbook Name:: postgresql
# Recipe:: server
#
# Author:: Joshua Timberman (<joshua@opscode.com>)
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright 2009-2011, Opscode, Inc.
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

include_recipe "postgresql::client"

# Create a group and user like the package will.
# Otherwise the templates fail.

group "postgres" do
  gid 26
end

user "postgres" do
  shell "/bin/bash"
  comment "PostgreSQL Server"
  home "/var/lib/pgsql"
  gid "postgres"
  system true
  uid 26
  supports manage_home: false
end

directory node["postgresql"]["dir"] do
  owner "postgres"
  group "postgres"
  recursive true
  action :create
end

node["postgresql"]["server"]["packages"].each do |pg_pack|
  package pg_pack
end

ha_enabled = node[:database][:ha][:enabled]

# We need to include the HA recipe early, before the config files are
# generated, but after the postgresql packages are installed since they live in
# the directory that will be mounted for HA
if ha_enabled
  include_recipe "postgresql::ha_storage"
end

template "#{node['postgresql']['sysconfig']}" do
  source "pgsql.sysconfig.erb"
  mode "0644"
  notifies :restart, "service[postgresql]", :delayed
end

# We need initdb to populate /var/lib/pgsql/data before we generate the config
# files (otherwise, later calls to initdb don't do anything and postgresql
# doesn't want to start).
#
#   - This is always done below for the non-SUSE case.
#
#   - For SUSE, however, we rely on the init script to call initdb on start.
#     But with HA, this won't happen: the OCF RA doesn't call initdb, so we
#     need to do it manually.
#     Also, on SUSE, there's no single initdb argument to the init script. So
#     we need to do a quick start / stop just for that :/
execute "Initial population of #{node.postgresql.dir}" do
  if node[:platform_family] == "suse"
    command "service postgresql start; service postgresql stop"
  else
    command "/sbin/service #{node['postgresql']['server']['service_name']} initdb #{node['postgresql']['initdb_locale']}"
  end
  not_if { (node[:platform_family] == "suse" && !ha_enabled) || ::FileTest.exist?(File.join(node.postgresql.dir, "PG_VERSION")) }
end

service "postgresql" do
  service_name node["postgresql"]["server"]["service_name"]
  supports restart: true, status: true, reload: true
  action [:enable, :start]
  provider Chef::Provider::CrowbarPacemakerService if node[:database][:ha][:enabled]
end

template "/etc/cron.daily/postgresql-logs" do
  source "cron-postgresql-logs.erb"
  owner "root"
  group "root"
  mode 0755
end
