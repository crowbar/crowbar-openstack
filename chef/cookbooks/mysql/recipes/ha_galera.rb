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
  mysql_service_name = "mariadb"

  bash "reload systemd after mariadb.service update" do
    code "systemctl daemon-reload"
    action :nothing
    subscribes :run,
      "file[mariadb.service]",
      :immediately
    subscribes :run,
      "file[delete mariadb.service]",
      :immediately
  end

  directory "/var/run/mysql/" do
    owner "mysql"
    group "root"
    mode "0755"
    action :create
  end

  # Temporary install mariadb unit as the "galera_new_cluster" bootstrap
  # script doesn't work with installed "mysql.service" unit. This unit file
  # will be delete again further down.
  file "mariadb.service" do
    path "/etc/systemd/system/mariadb.service"
    content lazy { ::File.open("/usr/share/mysql/systemd/mariadb.service").read }
    mode "0644"
  end

  execute "mysql_install_db" do
    command "mysql_install_db"
    action :run
  end

  # Initialize cluster on the founder node, this will start mariadb
  # via systemctl. We stop it again after the bootstrap.
  execute "boostrapping first mariadb galera cluster node" do
    command "galera_new_cluster"
    action :run
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
    subscribes :create,
      "file[delete mariadb.service]",
      :immediately
    action :nothing
  end

  file "delete mariadb.service" do
    path "/etc/systemd/system/mariadb.service"
    action :delete
  end
end

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end

transaction_objects = []
service_name = "galera"

vip_primitive = "vip-admin-#{CrowbarDatabaseHelper.get_ha_vhostname(node)}"
ip_addr = CrowbarDatabaseHelper.get_listen_address(node)

vip_op = {}
vip_op["monitor"] = {}
vip_op["monitor"]["interval"] = "10s"

pacemaker_primitive vip_primitive do
  agent "ocf:heartbeat:IPaddr2"
    params ({
      "ip" => ip_addr
    })
  op vip_op
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

transaction_objects << "pacemaker_primitive[#{vip_primitive}]"

cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node, "database-server")
nodes_names = cluster_nodes.map { |n| n[:hostname] }

mysql_op = {}
mysql_op["monitor"] = {}
mysql_op["monitor"]["interval"] = "10s"
mysql_op["monitor"]["role"] = "Master"

pacemaker_primitive service_name do
  agent resource_agent
  op mysql_op
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

ms_location_name = openstack_pacemaker_controller_only_location_for ms_name
transaction_objects.push("pacemaker_location[#{ms_location_name}]")

# Make sure VIP is running on a node where MySQL is in a good shape
# (= node is successfully promoted to Master)
colocation_constraint = "col-vip-with-#{service_name}"
pacemaker_colocation colocation_constraint do
  score "inf"
  resources "#{vip_primitive} #{ms_name}:Master"
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_colocation[#{colocation_constraint}]"

order_constraint = "o-#{service_name}-vip"
pacemaker_order order_constraint do
  score "Mandatory"
  ordering "#{ms_name}:promote #{vip_primitive}:start"
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_order[#{order_constraint}]"

pacemaker_transaction "galera service" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end
