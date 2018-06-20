ha_enabled = node[:aodh][:ha][:server][:enabled]

node[:aodh][:platform][:packages].each do |p|
  package p
end


db_settings = fetch_database_settings

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-aodh_database" if ha_enabled

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
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-aodh_database" if ha_enabled

directory "/var/cache/aodh" do
  owner node[:aodh][:user]
  group "root"
  mode 00755
  action :create
end unless node[:platform_family] == "suse"

if node[:aodh][:api][:protocol] == "https"
  ssl_setup "setting up ssl for aodh" do
    generate_certs node[:aodh][:ssl][:generate_certs]
    certfile node[:aodh][:ssl][:certfile]
    keyfile node[:aodh][:ssl][:keyfile]
    group node[:aodh][:group]
    fqdn node[:fqdn]
    cert_required node[:aodh][:ssl][:cert_required]
    ca_certs node[:aodh][:ssl][:ca_certs]
  end
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(
  node, node[:aodh][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-aodh_keystone_register" if ha_enabled

keystone_register "register aodh user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  project_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give aodh user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  project_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

# Create aodh service
keystone_register "register aodh service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
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
  auth register_auth_hash
  endpoint_service "aodh"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{aodh_protocol}://#{my_public_host}:#{aodh_port}"
  endpoint_adminURL "#{aodh_protocol}://#{my_admin_host}:#{aodh_port}"
  endpoint_internalURL "#{aodh_protocol}://#{my_admin_host}:#{aodh_port}"
  action :add_endpoint
end

crowbar_pacemaker_sync_mark "create-aodh_keystone_register" if ha_enabled

db_connection = fetch_database_connection_string(node[:aodh][:db])

if node[:aodh][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:aodh][:ha][:ports][:api]
else
  bind_host = node[:aodh][:api][:host]
  bind_port = node[:aodh][:api][:port]
end

memcached_servers = MemcachedHelper.get_memcached_servers(
  ha_enabled ? CrowbarPacemakerHelper.cluster_nodes(node, "aodh-server") : [node]
)

memcached_instance("aodh-server")

template node[:aodh][:config_file] do
  source "aodh.conf.erb"
  owner "root"
  group node[:aodh][:group]
  mode "0640"
  variables(
    debug: node[:aodh][:debug],
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: keystone_settings,
    memcached_servers: memcached_servers,
    bind_host: bind_host,
    bind_port: bind_port,
    database_connection: db_connection,
    node_hostname: node["hostname"],
    aodh_ssl: node[:aodh][:ssl],
    evaluation_interval: node[:aodh][:evaluation_interval],
    alarm_history_ttl: node[:aodh][:alarm_history_ttl]
  )
  notifies :reload, resources(service: "apache2")
end

crowbar_pacemaker_sync_mark "wait-aodh_db_sync" if ha_enabled

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

crowbar_pacemaker_sync_mark "create-aodh_db_sync" if ha_enabled

service "aodh-api" do
  service_name node[:aodh][:api][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:disable, :stop]
  ignore_failure true
end

crowbar_openstack_wsgi "WSGI entry for aodh-api" do
  bind_host bind_host
  bind_port bind_port
  daemon_process "aodh-api"
  user node[:aodh][:user]
  group node[:aodh][:group]
  script_alias "/srv/www/aodh-api/app.wsgi"
  pass_authorization true
  limit_request_body 114688
  ssl_enable node[:aodh][:api][:protocol] == "https"
  ssl_certfile node[:aodh][:ssl][:certfile]
  ssl_keyfile node[:aodh][:ssl][:keyfile]
  if node[:aodh][:ssl][:cert_required]
    ssl_cacert node[:aodh][:ssl][:ca_certs]
  end
end

apache_site "aodh-api.conf" do
  enable true
end

use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

service "aodh-evaluator" do
  service_name node[:aodh][:evaluator][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:aodh][:config_file])
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "aodh-evaluator" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "aodh-notifier" do
  service_name node[:aodh][:notifier][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:aodh][:config_file])
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "aodh-notifier" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "aodh-listener" do
  service_name node[:aodh][:listener][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:aodh][:config_file])
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "aodh-listener" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

if ha_enabled
  log "HA support for aodh is enabled"
  include_recipe "aodh::aodh_ha"
else
  log "HA support for aodh is disabled"
end
