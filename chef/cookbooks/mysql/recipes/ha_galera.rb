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

["galera-3-wsrep-provider", "mariadb-tools", "xtrabackup", "socat"].each do |p|
  package p
end

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
end

unless node[:database][:galera_bootstrapped]
  if CrowbarPacemakerHelper.is_cluster_founder?(node)
    # To bootstrap for the first time, start galera on one node
    # to set up the seed sst user.

    template "temporary bootstrap /etc/my.cnf.d/galera.cnf" do
      path "/etc/my.cnf.d/galera.cnf"
      source "galera.cnf.erb"
      owner "root"
      group "mysql"
      mode "0640"
      variables(
        cluster_addresses: "gcomm://",
        sstuser: "root",
        sstuser_password: ""
      )
    end

    case node[:platform_family]
    when "rhel", "fedora"
      mysql_service_name = "mysqld"
    else
      mysql_service_name = "mysql"
    end

    # use the initial root:'' credentials to set up the new user. The
    # unauthenticated root user is later removed in server.rb after the
    # bootstraping. Once the cluster has started other nodes will pick up on
    # the sstuser and we are able to use these credentails.
    db_settings = fetch_database_settings
    db_connection = db_settings[:connection].dup
    db_connection[:host] = "localhost"
    db_connection[:username] = "root"
    db_connection[:password] = ""

    service "mysql-temp start" do
      service_name mysql_service_name
      supports status: true, restart: true, reload: true
      action :start
    end

    database_user "create state snapshot transfer user" do
      connection db_connection
      username "sstuser"
      password node[:database][:mysql][:sstuser_password]
      host "localhost"
      provider db_settings[:user_provider]
      action :create
    end

    database_user "grant sstuser root privileges" do
      connection db_connection
      username "sstuser"
      password node[:database][:mysql][:sstuser_password]
      host "localhost"
      provider db_settings[:user_provider]
      action :grant
    end

    service "mysql-temp stop" do
      service_name mysql_service_name
      supports status: true, restart: true, reload: true
      action :stop
    end
  end
end

service_name = "galera"

cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node)
nodes_names = cluster_nodes.map { |n| n[:hostname] }

cluster_addresses = "gcomm://" + nodes_names.join(",")

template "/etc/my.cnf.d/galera.cnf" do
  source "galera.cnf.erb"
  owner "root"
  group "mysql"
  mode "0640"
  variables(
    cluster_addresses: cluster_addresses,
    sstuser: "sstuser",
    sstuser_password: node[:database][:mysql][:sstuser_password]
  )
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages and configurations installed before we create the
# pacemaker resources
crowbar_pacemaker_sync_mark "sync-database_before_ha" do
  revision node[:database]["crowbar-revision"]
end

transaction_objects = []

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-database_ha_resources" do
  revision node[:database]["crowbar-revision"]
end

pacemaker_primitive service_name do
  agent resource_agent
  params({
    "enable_creation" => true,
    "wsrep_cluster_address" => cluster_addresses,
    "check_user" => "monitoring",
    "socket" => "/var/run/mysql/mysql.sock",
    "datadir" => node[:database][:mysql][:datadir],
    "log" => "/var/log/mysql/mysql_error.log"
  })
  op node[:mysql][:ha][:op]
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

transaction_objects.push("pacemaker_primitive[#{service_name}]")

ms_name = "ms-#{service_name}"
pacemaker_ms ms_name do
  rsc service_name
  meta(
    "master-max" => nodes_names.size,
    "clone-max" => nodes_names.size,
    "ordered" => "false",
    "interleave" => "false",
    "notify" => "true"
  )
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

transaction_objects.push("pacemaker_ms[#{ms_name}]")

ms_location_name = openstack_pacemaker_controller_only_location_for ms_name
transaction_objects << "pacemaker_location[#{ms_location_name}]"

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
ruby_block "wait galera bootstrap" do
  seconds = 300
  block do
    require "timeout"
    begin
      cmd = "mysql -u '' -N -B " \
        "-e \"SHOW STATUS WHERE Variable_name='wsrep_local_state_comment';\" | cut -f 2"
      sync_state = ""
      Timeout.timeout(seconds) do
        while sync_state != "Synced"
          sleep(1)
          get_state = Mixlib::ShellOut.new(cmd).run_command
          sync_state = get_state.stdout.chop
        end
      end
    rescue Timeout::Error
      message = "Galera cluster did not start after #{seconds} seconds. " \
        "Check pacemaker and mysql log files manually for possible errors."
      Chef::Log.fatal(message)
      raise message
    end
  end
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
  options ["mysql-check user monitoring"]
  stick ({ "on" => "dst" })
  servers ha_servers
  action :nothing
end.run_action(:create)
