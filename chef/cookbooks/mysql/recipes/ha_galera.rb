#
# Cookbook Name:: mysql
# Recipe:: ha_galera
#
# Copyright 2017, SUSE Linux GmbH.
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

resource_agent = "ocf:heartbeat:galera"

package "galera-3"

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-database_before_ha" do
  revision node[:database]["crowbar-revision"]
end

unless node[:database][:galera_bootstrapped]
  mysql_service_name = "mysql"

  directory "/var/run/mysql/" do
    owner "mysql"
    group "root"
    mode "0755"
    action :create
  end

  execute "mysql_install_db" do
    command "mysql_install_db"
    action :run
  end

  # Start mariadb on the founder. At this point, the configuration file has no
  # cluster members defined, so it will listen for the other nodes to join it.
  # We will stop it again after bootstrapping.
  service "starting mysql on cluster founder" do
    service_name mysql_service_name
    action :start
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  execute "assign-root-password-galera" do
    command "/usr/bin/mysqladmin -u root password \"#{node[:mysql][:server_root_password]}\""
    action :run
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    only_if "/usr/bin/mysql -u root -e 'show databases;'"
  end

  # Wait on all nodes for the founder to complete the bootstrap
  crowbar_pacemaker_sync_mark "sync-database_after_bootstrap_founder" do
    revision node[:database]["crowbar-revision"]
  end

  service "starting mysql on remaining nodes" do
    service_name mysql_service_name
    action :start
    not_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  execute "assign-root-password-galera" do
    command "/usr/bin/mysqladmin -u root password \"#{node[:mysql][:server_root_password]}\""
    action :run
    not_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    only_if "/usr/bin/mysql -u root -e 'show databases;'"
  end

  crowbar_pacemaker_sync_mark "sync-database_after_bootstrap_rest" do
    revision node[:database]["crowbar-revision"]
  end

  service "stop mysql after boostrap completed" do
    service_name mysql_service_name
    action :stop
  end

  ruby_block "mark node for galera bootstrap" do
    block do
      node.set[:database][:galera_bootstrapped] = true
      node.save
    end
    notifies :create, "template[/etc/my.cnf]"
  end
end

transaction_objects = []

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end

service_name = "galera"

cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node, "database-server")
nodes_names = cluster_nodes.map { |n| n[:hostname] }

pacemaker_primitive service_name do
  agent resource_agent
  params ({
    "enable_creation" => true,
    "wsrep_cluster_address" => "gcomm://" + nodes_names.join(","),
    "check_user" => "root",
    "check_passwd" => node[:database][:mysql][:server_root_password],
    "socket" => "/var/run/mysql/mysql.sock"
  })
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

transaction_objects.push("pacemaker_primitive[#{service_name}]")

ms_name = "ms-#{service_name}"
pacemaker_ms ms_name do
  rsc service_name
  meta(
    "master-max" => nodes_names.size,
    "ordered" => "false",
    "interleave" => "false",
    "notify" => "true"
  )
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

transaction_objects.push("pacemaker_ms[#{ms_name}]")

pacemaker_transaction "galera service" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end
