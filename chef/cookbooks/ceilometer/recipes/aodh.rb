ha_enabled = node[:ceilometer][:ha][:server][:enabled]

unless node[:ceilometer][:use_mongodb]

  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

  crowbar_pacemaker_sync_mark "wait-aodh_database"

  # Create the Aodh Database
  database "create #{node[:ceilometer][:aodh][:db][:database]} database" do
    connection db_settings[:connection]
    database_name node[:ceilometer][:aodh][:db][:database]
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "create aodh database user" do
    host "%"
    connection db_settings[:connection]
    username node[:ceilometer][:aodh][:db][:user]
    password node[:ceilometer][:aodh][:db][:password]
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "grant database access for aodh database user" do
    connection db_settings[:connection]
    username node[:ceilometer][:aodh][:db][:user]
    password node[:ceilometer][:aodh][:db][:password]
    database_name node[:ceilometer][:aodh][:db][:database]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-aodh_database"
end
# FIXME: nothing for mongdb...?

aodh_service_user = node[:ceilometer][:aodh][:service_user]
aodh_service_password = node[:ceilometer][:aodh][:service_password]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:ceilometer][:aodh][:api][:protocol] == "https", ha_enabled)

keystone_register "register aodh user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name aodh_service_user
  user_password aodh_service_password
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give aodh user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  token keystone_settings["admin_token"]
  user_name aodh_service_user
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

aodh_protocol = node[:ceilometer][:aodh][:api][:protocol]
aodh_port = node[:ceilometer][:aodh][:api][:port]

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

db_name = node[:ceilometer][:aodh][:db][:database]
db_user = node[:ceilometer][:aodh][:db][:user]
db_password = node[:ceilometer][:aodh][:db][:password]
db_connection =
  "#{db_settings[:url_scheme]}://#{db_user}:#{db_password}@#{db_settings[:address]}/#{db_name}"

if node[:ceilometer][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:ceilometer][:aodh][:ha][:ports][:api]
else
  bind_host = node[:ceilometer][:aodh][:api][:host]
  bind_port = node[:ceilometer][:aodh][:api][:port]
end

internal_auth_url_v2 = KeystoneHelper.versioned_service_URL(
  keystone_settings["protocol"], keystone_settings["internal_url_host"],
  keystone_settings["service_port"], "2.0")

template "/etc/aodh/aodh.conf" do
  source "aodh.conf.erb"
  owner "root"
  group node[:ceilometer][:aodh][:group]
  mode "0640"
  variables(
    debug: node[:ceilometer][:debug],
    verbose: node[:ceilometer][:verbose],
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: keystone_settings,
    aodh_service_user: aodh_service_user,
    aodh_service_password: aodh_service_password,
    internal_auth_url_v2: internal_auth_url_v2,
    bind_host: bind_host,
    bind_port: bind_port,
    database_connection: db_connection,
    node_hostname: node["hostname"],
    alarm_threshold_evaluation_interval: node[:ceilometer][:alarm_threshold_evaluation_interval]
  )
end

service "aodh-api" do
  service_name node[:ceilometer][:aodh][:api][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "aodh-evaluator" do
  service_name node[:ceilometer][:aodh][:evaluator][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "aodh-notifier" do
  service_name node[:ceilometer][:aodh][:notifier][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "aodh-listener" do
  service_name node[:ceilometer][:aodh][:listener][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources("template[/etc/aodh/aodh.conf]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

if ha_enabled
  log "HA support for aodh is enabled"
  include_recipe "ceilometer::aodh_ha"
else
  log "HA support for aodh is disabled"
end
