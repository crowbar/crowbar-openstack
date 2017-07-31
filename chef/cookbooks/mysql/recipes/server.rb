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

ha_enabled = node[:database][:ha][:enabled]

include_recipe "mysql::client"

if platform_family?("debian")

  directory "/var/cache/local/preseeding" do
    owner "root"
    group "root"
    mode 0755
    recursive true
  end

  template "/var/cache/local/preseeding/mysql-server.seed" do
    source "mysql-server.seed.erb"
    owner "root"
    group "root"
    mode "0600"
  end

  template "/etc/mysql/debian.cnf" do
    source "debian.cnf.erb"
    owner "root"
    group "root"
    mode "0600"
  end

  execute "preseed mysql-server" do
    command "debconf-set-selections /var/cache/local/preseeding/mysql-server.seed"
    only_if "test -f /var/cache/local/preseeding/mysql-server.seed"
  end
end

# For Crowbar, we need to set the address to bind - default to admin node.
addr = node["mysql"]["bind_address"] || ""
newaddr = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
if addr != newaddr
  node["mysql"]["bind_address"] = newaddr
  node.save
end

package "mysql-server" do
  package_name "mysql" if node[:platform_family] == "suse"
  action :install
end

case node[:platform_family]
when "rhel", "fedora"
  mysql_service_name = "mysqld"
else
  mysql_service_name = "mysql"
end

service "mysql" do
  service_name mysql_service_name
  if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
    restart_command "restart mysql"
    stop_command "stop mysql"
    start_command "start mysql"
  end
  supports status: true, restart: true, reload: true
  action :enable
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

directory node[:mysql][:tmpdir] do
  owner "mysql"
  group "mysql"
  mode "0700"
  action :create
end

directory node[:mysql][:logdir] do
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

cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node, "database-server")
nodes_names = cluster_nodes.map { |n| n[:hostname] }

template "/etc/my.cnf" do
  source "my.cnf.erb"
  owner "root"
  group "mysql"
  mode "0640"
  variables(
    nodes_names: nodes_names
  )
  notifies :run, resources(script: "handle mysql restart"), :immediately if platform_family?("debian")
  notifies :restart, "service[mysql]", :immediately if platform_family?(%w{rhel suse fedora})
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

# set the root password on platforms
# that don't support pre-seeding
unless platform_family?("debian")

  execute "assign-root-password" do
    command "/usr/bin/mysqladmin -u root password \"#{node['mysql']['server_root_password']}\""
    action :run
    only_if "/usr/bin/mysql -u root -e 'show databases;'"
  end

end

grants_path = value_for_platform_family(
  ["rhel", "suse", "fedora"] => "/etc/mysql_grants.sql",
  "default" => "/etc/mysql/grants.sql"
)

grants_key = value_for_platform_family(
  ["rhel", "suse", "fedora"] => "/etc/applied_grants",
  "default" => "/etc/mysql/applied_grants"
)

template grants_path do
  source "grants.sql.erb"
  owner "root"
  group "root"
  mode "0600"
  action :create
  not_if { File.exist?("#{grants_key}") }
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

execute "mysql-install-privileges" do
  command "/usr/bin/mysql -u root #{node['mysql']['server_root_password'].empty? ? '' : '-p' }#{node['mysql']['server_root_password']} < #{grants_path}"
  action :nothing
  subscribes :run, resources("template[#{grants_path}]"), :immediately
end

file grants_path do
  backup false
  action :delete
end

file grants_key do
  owner "root"
  group "root"
  mode "0600"
  action :create_if_missing
end
