ha_enabled = node[:ceilometer][:ha][:server][:enabled]

node[:aodh][:platform][:packages].each do |p|
  package p
end

# mongdb setup has been already done by server.rb recipe
unless node[:ceilometer][:use_mongodb]
  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

  crowbar_pacemaker_sync_mark "wait-aodh_database"

  # Create the Aodh Database
  database "create #{node[:aodh][:db][:database]} database" do
    connection db_settings[:connection]
    database_name node[:aodh][:db][:database]
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "create aodh database user" do
    host "%"
    connection db_settings[:connection]
    username node[:aodh][:db][:user]
    password node[:aodh][:db][:password]
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "grant database access for aodh database user" do
    connection db_settings[:connection]
    username node[:aodh][:db][:user]
    password node[:aodh][:db][:password]
    database_name node[:aodh][:db][:database]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-aodh_database"
end

directory "/var/cache/aodh" do
  owner node[:aodh][:user]
  group "root"
  mode 00755
  action :create
end unless node[:platform_family] == "suse"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:aodh][:api][:protocol] == "https", ha_enabled)

keystone_register "register aodh user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give aodh user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

# Create aodh service
keystone_register "register aodh service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  service_name "aodh"
  service_type "alarming"
  service_description "Openstack Telemetry Alarming Service"
  action :add_service
end

aodh_protocol = node[:aodh][:api][:protocol]
aodh_port = node[:aodh][:api][:port]

keystone_register "register aodh endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  endpoint_service "aodh"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{aodh_protocol}://#{my_public_host}:#{aodh_port}"
  endpoint_adminURL "#{aodh_protocol}://#{my_admin_host}:#{aodh_port}"
  endpoint_internalURL "#{aodh_protocol}://#{my_admin_host}:#{aodh_port}"
  action :add_endpoint_template
end

if node[:ceilometer][:use_mongodb]
  db_connection = nil

  if node[:ceilometer][:ha][:server][:enabled]
    db_hosts = search(:node,
                      "ceilometer_ha_mongodb_replica_set_member:true AND roles:ceilometer-server AND "\
                      "ceilometer_config_environment:#{node[:ceilometer][:config][:environment]}"
                     )
    unless db_hosts.empty?
      mongodb_servers = db_hosts.map { |s| "#{Chef::Recipe::Barclamp::Inventory.get_network_by_type(s, "admin").address}:#{s[:ceilometer][:mongodb][:port]}" }
      db_connection = "mongodb://#{mongodb_servers.sort.join(",")}/ceilometer?replicaSet=#{node[:ceilometer][:ha][:mongodb][:replica_set][:name]}"
    end
  end

  # if this is a cluster, but the replica set member attribute hasn't
  # been set on any node (yet), we just fallback to using the first
  # ceilometer-server node
  if db_connection.nil?
    db_hosts = search_env_filtered(:node, "roles:ceilometer-server")
    db_host = db_hosts.first || node
    mongodb_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
    db_connection = "mongodb://#{mongodb_ip}:#{db_host[:ceilometer][:mongodb][:port]}/ceilometer"
  end
else
  db_name = node[:aodh][:db][:database]
  db_user = node[:aodh][:db][:user]
  db_password = node[:aodh][:db][:password]
  db_connection =
    "#{db_settings[:url_scheme]}://#{db_user}:#{db_password}@#{db_settings[:address]}/#{db_name}"
end

if node[:ceilometer][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:aodh][:ha][:ports][:api]
else
  bind_host = node[:aodh][:api][:host]
  bind_port = node[:aodh][:api][:port]
end

internal_auth_url_v2 = KeystoneHelper.versioned_service_URL(
  keystone_settings["protocol"], keystone_settings["internal_url_host"],
  keystone_settings["service_port"], "2.0")

template "/etc/aodh/aodh.conf" do
  source "aodh.conf.erb"
  owner "root"
  group node[:aodh][:group]
  mode "0640"
  variables(
    debug: node[:ceilometer][:debug],
    verbose: node[:ceilometer][:verbose],
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: keystone_settings,
    internal_auth_url_v2: internal_auth_url_v2,
    bind_host: bind_host,
    bind_port: bind_port,
    database_connection: db_connection,
    node_hostname: node["hostname"],
    alarm_threshold_evaluation_interval: node[:ceilometer][:alarm_threshold_evaluation_interval]
  )
end

crowbar_pacemaker_sync_mark "wait-aodh_db_sync"

execute "aodh-dbsync" do
  command "aodh-dbsync"
  action :run
  user node[:aodh][:user]
  group node[:aodh][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:aodh][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for aodh db_sync" do
  block do
    node.set[:aodh][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[aodh-dbsync]", :immediately
end

crowbar_pacemaker_sync_mark "create-aodh_db_sync"

service "aodh-api" do
  service_name node[:aodh][:api][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "aodh-evaluator" do
  service_name node[:aodh][:evaluator][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "aodh-notifier" do
  service_name node[:aodh][:notifier][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "aodh-listener" do
  service_name node[:aodh][:listener][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

if ha_enabled
  log "HA support for aodh is enabled"
  include_recipe "aodh::aodh_ha"
else
  log "HA support for aodh is disabled"
end
