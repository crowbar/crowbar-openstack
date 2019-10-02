#
# Cookbook Name:: watcher
# Recipe:: api
#
#

include_recipe "#{@cookbook_name}::common"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:watcher][:api][:protocol] == "https"
  ssl_setup "setting up ssl for watcher" do
    generate_certs node[:watcher][:ssl][:generate_certs]
    certfile node[:watcher][:ssl][:certfile]
    keyfile node[:watcher][:ssl][:keyfile]
    group node[:watcher][:group]
    fqdn node[:fqdn]
    cert_required node[:watcher][:ssl][:cert_required]
    ca_certs node[:watcher][:ssl][:ca_certs]
  end
end

network_settings = WatcherHelper.network_settings(node)

# create the state directory
directory node[:watcher][:state_path] do
  owner node[:watcher][:user]
  group node[:watcher][:group]
  mode 0o755
  action :create
  recursive true
end

template node[:watcher][:api][:config_file] do
  source "watcher-api.conf.erb"
  owner "root"
  group node[:watcher][:group]
  mode 0o640
  variables(
    bind_host: network_settings[:api][:bind_host],
    bind_port: network_settings[:api][:bind_port],
    keystone_settings: keystone_settings,
    memcached_servers: MemcachedHelper.get_memcached_servers(node,
      CrowbarPacemakerHelper.cluster_nodes(node, "watcher-server")),
    rabbit_settings: fetch_rabbitmq_settings
  )
  notifies :restart, "service[#{node[:watcher][:api][:service_name]}]"
end

ha_enabled = node[:watcher][:ha][:enabled]
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node,
  node[:watcher][:api][:protocol] == "https", ha_enabled)

# If we let the service bind to all IPs, then the service is obviously usable
# from the public network. Otherwise, the endpoint URL should use the unique
# IP that will be listened on.
endpoint_admin_ip = my_admin_host
endpoint_public_ip =
  if node[:watcher][:api][:bind_open_address]
    my_public_host
  else
    my_admin_host
  end
api_port = node["watcher"]["api"]["bind_port"]
watcher_protocol = node[:watcher][:api][:protocol]

crowbar_pacemaker_sync_mark "wait-watcher_register_service" if ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

keystone_register "register watcher service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "watcher"
  service_type "infra-optim"
  service_description "Openstack Watcher Infrastructure Optimization Service"
  action :add_service
end

keystone_register "register watcher endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "watcher"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{watcher_protocol}://#{endpoint_public_ip}:#{api_port}"
  endpoint_adminURL "#{watcher_protocol}://#{endpoint_admin_ip}:#{api_port}"
  endpoint_internalURL "#{watcher_protocol}://#{endpoint_admin_ip}:#{api_port}"
  action :add_endpoint
end

crowbar_pacemaker_sync_mark "create-watcher_register_service" if ha_enabled

crowbar_pacemaker_sync_mark "wait-watcher_db_manage" if ha_enabled

is_founder = CrowbarPacemakerHelper.is_cluster_founder?(node)

execute "watcher-db-manage" do
  user node[:watcher][:user]
  group node[:watcher][:group]
  command "watcher-db-manage --config-file #{node[:watcher][:api][:config_file]} upgrade"
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:watcher][:db_managed] && (!ha_enabled || is_founder) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for watcher db_managed" do
  block do
    node.set[:watcher][:db_managed] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[watcher-db-manage]", :immediately
end

crowbar_pacemaker_sync_mark "create-watcher_db_manage" if ha_enabled

watcher_service "api"
watcher_service "applier"
watcher_service "decision_engine"
