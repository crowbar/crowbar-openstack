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

unless node[:database][:galera_bootstrapped]
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

  crowbar_pacemaker_sync_mark "sync-database_after_install_db" do
    revision node[:database]["crowbar-revision"]
  end
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-database_before_ha" do
  revision node[:database]["crowbar-revision"]
end

transaction_objects = []

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end

service_name = "galera"

cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node)
nodes_names = cluster_nodes.map { |n| n[:hostname] }

pacemaker_primitive service_name do
  agent resource_agent
  params({
    "enable_creation" => true,
    "wsrep_cluster_address" => "gcomm://" + nodes_names.join(","),
    "check_user" => "''",
    "socket" => "/var/run/mysql/mysql.sock"
  })
  op({
    "monitor" => {
      "interval" => "20s",
      "role" => "Master"
    }
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

# The pacemaker galera resources agent will now bootstrap the cluster.
# Which might take a while. Wait for that to complete by watching the
# "wsrep_local_state_comment" status variable on all cluster nodes to reach
# the "Synced" state, before continuing with the rest of the recipe.
script "wait galera bootstrap" do
  interpreter "bash"
  code <<-EOH
    sync_state=""
    while [[ $sync_state != "Synced" ]]; do
      sleep 1
      sync_state=$(mysql -u "''" -N -B -e "SHOW STATUS WHERE Variable_name='wsrep_local_state_comment';" | cut -f 2)
    done
  EOH
  not_if { node[:database][:galera_bootstrapped] }
end

ruby_block "mark node for galera bootstrap" do
  block do
    node.set[:database][:galera_bootstrapped] = true
    node.save
  end
  not_if { node[:database][:galera_bootstrapped] }
end

crowbar_pacemaker_sync_mark "sync-database_boostrapped" do
  revision node[:database]["crowbar-revision"]
end

execute "assign-root-password-galera" do
  command "/usr/bin/mysqladmin -u root password \"#{node[:mysql][:server_root_password]}\""
  action :run
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  only_if "/usr/bin/mysql -u root -e 'show databases;'"
end

crowbar_pacemaker_sync_mark "sync-database_root_password" do
  revision node[:database]["crowbar-revision"]
end

include_recipe "crowbar-pacemaker::haproxy"

ha_servers = CrowbarPacemakerHelper.haproxy_servers_for_service(
  node, "mysql", "database-server", "admin_port"
).sort_by { |s| s["name"] }

# Let all nodes but one act as backup (standby) servers.
# Backup server is only used when non-backup one is down. Thus we prevent possible deadlocks
# from OpenStack services writing to the database on different nodes at once.
ha_servers = ha_servers.each_with_index do |n, i|
  n["backup"] = i > 0
  # lower the number of unsuccessful checks needed for declaring server DOWN
  n["fall"] = 2
  # lower the interval checking after first failure is found
  n["fastinter"] = 1000
end

haproxy_loadbalancer "galera" do
  address CrowbarDatabaseHelper.get_listen_address(node)
  port 3306
  mode "tcp"
  options ["mysql-check user haproxy"]
  stick ({ "on" => "dst" })
  servers ha_servers
  action :nothing
end.run_action(:create)
