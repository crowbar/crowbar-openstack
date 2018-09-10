#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2008-2011, Opscode, Inc.
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

include_recipe "mysql::client"
include_recipe "database::client"

ha_enabled = node[:database][:ha][:enabled]

# For Crowbar, we need to set the address to bind - default to admin node.
addr = node[:database][:mysql][:bind_address] || ""
newaddr = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
if addr != newaddr
  node[:database][:mysql][:bind_address] = newaddr
  node.save
end

package node[:mysql][:mysql_server]

case node[:platform_family]
when "rhel", "fedora"
  mysql_service_name = "mysqld"
else
  mysql_service_name = "mysql"
end

service "mysql" do
  service_name mysql_service_name
  if ha_enabled
    supports status: true,
             restart: true,
             reload: true,
             restart_crm_resource: true,
             pacemaker_resource: "galera",
             crm_resource_stop_cmd: "force-demote",
             crm_resource_start_cmd: "force-promote"
  else
    supports status: true,
             restart: true,
             reload: true
  end
  action :enable
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end
utils_systemd_service_restart "mysql" do
  action ha_enabled ? :disable : :enable
end

directory node[:database][:mysql][:tmpdir] do
  owner "mysql"
  group "mysql"
  mode "0700"
  action :create
end

script "handle mysql restart" do
  interpreter "bash"
  action :nothing
  code <<EOC
service mysql stop
rm /var/lib/mysql/ib_logfile?
service mysql start
EOC
end

if node[:database][:mysql][:ssl][:enabled]
  ssl_setup "setting up ssl for mysql" do
    generate_certs node[:database][:mysql][:ssl][:generate_certs]
    keyfile node[:database][:mysql][:ssl][:keyfile]
    certfile node[:database][:mysql][:ssl][:certfile]
    ca_certs node[:database][:mysql][:ssl][:ca_certs]
    cert_required !(
      node[:database][:mysql][:ssl][:generate_certs] ||
      node[:database][:mysql][:ssl][:insecure])
    group "mysql"
    fqdn CrowbarDatabaseHelper.get_listen_address(node)
  end
end

template "/etc/my.cnf.d/72-openstack.cnf" do
  source "my.cnf.erb"
  owner "root"
  group "mysql"
  mode "0640"
  notifies :restart, "service[mysql]", :immediately
end

file "/etc/my.cnf.d/openstack.cnf" do
  action :delete
  notifies :restart, "service[mysql]"
end

template "/etc/my.cnf.d/73-ssl.cnf" do
  source "ssl.cnf.erb"
  owner "root"
  group "mysql"
  mode "0640"
  notifies :restart, "service[mysql]", :immediately
end

file "/etc/my.cnf.d/ssl.cnf" do
  action :delete
  notifies :restart, "service[mysql]"
end

template "/etc/my.cnf.d/71-logging.cnf" do
  source "logging.cnf.erb"
  owner "root"
  group "mysql"
  mode "0640"
  variables(
    slow_query_logging_enabled: node[:database][:mysql][:slow_query_logging]
  )
  notifies :restart, "service[mysql]", :immediately
end

file "/etc/my.cnf.d/logging.cnf" do
  action :delete
  notifies :restart, "service[mysql]"
end

template "/etc/my.cnf.d/74-tuning.cnf" do
  source "tuning.cnf.erb"
  owner "root"
  group "mysql"
  mode "0640"
  variables(
    innodb_buffer_pool_size: node[:database][:mysql][:innodb_buffer_pool_size],
    innodb_flush_log_at_trx_commit: node[:database][:mysql][:innodb_flush_log_at_trx_commit],
    innodb_buffer_pool_instances: node[:database][:mysql][:innodb_buffer_pool_instances],
    max_connections: node[:database][:mysql][:max_connections],
    tmp_table_size: node[:database][:mysql][:tmp_table_size],
    max_heap_table_size: node[:database][:mysql][:max_heap_table_size]
  )
  notifies :restart, "service[mysql]", :immediately
end

file "/etc/my.cnf.d/tuning.cnf" do
  action :delete
  notifies :restart, "service[mysql]"
end

unless Chef::Config[:solo]
  ruby_block "save node data" do
    block do
      node.save
    end
    action :create
  end
end

if ha_enabled
  log "HA support for mysql is enabled"
  include_recipe "mysql::ha_galera"
else
  log "HA support for mysql is disabled"
end

server_root_password = node[:database][:mysql][:server_root_password]

execute "assign-root-password" do
  command "/usr/bin/mysqladmin -u root password \"#{server_root_password}\""
  action :run
  not_if { ha_enabled } # password already set as part of the ha bootstrap
  only_if "/usr/bin/mysql -u root -e 'show databases;'"
end

db_settings = fetch_database_settings
db_connection = db_settings[:connection].dup
db_connection[:host] = "localhost"
db_connection[:username] = "root"
db_connection[:password] = node[:database][:mysql][:server_root_password]
db_connection[:ssl] = {}

unless node[:database][:database_bootstrapped]
  database_user "create db_maker database user" do
    connection db_connection
    username "db_maker"
    password node[:database][:db_maker_password]
    host "%"
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "grant db_maker access" do
    connection db_connection
    username "db_maker"
    password node[:database][:db_maker_password]
    host "%"
    privileges db_settings[:privs] + [
      "ALTER ROUTINE",
      "CREATE ROUTINE",
      "CREATE TEMPORARY TABLES",
      "CREATE USER",
      "CREATE VIEW",
      "EXECUTE",
      "GRANT OPTION",
      "LOCK TABLES",
      "RELOAD",
      "SHOW DATABASES",
      "SHOW VIEW",
      "TRIGGER"
    ]
    provider db_settings[:user_provider]
    require_ssl node[:database][:mysql][:ssl][:enabled]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database "drop test database" do
    connection db_connection
    database_name "test"
    provider db_settings[:provider]
    action :drop
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  ["localhost", node[:hostname]].each do |hostname|
    database_user "drop anonymous database user at #{hostname}" do
      connection db_connection
      username ""
      host hostname
      provider db_settings[:user_provider]
      action :drop
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end

  # Drop unneeded root users, we only use root access via unix domain socket
  ["127.0.0.1", "::1", node[:hostname]].each do |hostname|
    database_user "drop unneeded root database user at #{hostname}" do
      connection db_connection
      username "root"
      host hostname
      provider db_settings[:user_provider]
      action :drop
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end
end

ruby_block "mark node for database bootstrap" do
  block do
    node.set[:database][:database_bootstrapped] = true
    node.save
  end
  not_if { node[:database][:database_bootstrapped] }
end

directory "/var/log/mysql/" do
  owner "mysql"
  group "root"
  mode "0755"
  action :create
end

directory "/var/run/mysqld/" do
  owner "mysql"
  group "root"
  mode "0755"
  action :create
end
