# Copyright 2011 Dell, Inc.
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

ha_enabled = node[:ceilometer][:ha][:server][:enabled]

if node[:ceilometer][:use_mongodb]
  include_recipe "ceilometer::mongodb" if !ha_enabled || node[:ceilometer][:ha][:mongodb][:replica_set][:member]

  # need to wait for mongodb to start even if it's on a different host
  # (ceilometer services need it running)
  mongodb_nodes = nil

  if ha_enabled
    mongodb_nodes = CeilometerHelper.replica_set_members(node)
  end

  # if we don't have HA enabled, then mongodb should be on the current host; if
  # we have HA enabled and the node is part of the replica set, then we're fine
  # too
  mongodb_nodes ||= [node]

  mongodb_addresses = mongodb_nodes.map{ |n| Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address }

  ruby_block "wait for mongodb start" do
    block do
      require "timeout"
      begin
        Timeout.timeout(120) do
          master_available = false
          while true
            mongodb_addresses.each do |mongodb_address|
              cmd = shell_out("mongo --quiet #{mongodb_address} --eval \"db.isMaster()['ismaster']\" 2> /dev/null")
              if cmd.exitstatus == 0 and cmd.stdout.strip == "true"
                master_available = true
                break
              end
            end

            break if master_available

            Chef::Log.debug("mongodb still not reachable")
            sleep(2)
          end
        end
      rescue Timeout::Error
        Chef::Log.warn("No master for mongodb on #{mongodb_addresses.join(',')} after trying for 2 minutes")
      end
    end
  end
else
  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

  crowbar_pacemaker_sync_mark "wait-ceilometer_database" if ha_enabled

  # Create the Ceilometer Database
  database "create #{node[:ceilometer][:db][:database]} database" do
      connection db_settings[:connection]
      database_name node[:ceilometer][:db][:database]
      provider db_settings[:provider]
      action :create
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "create ceilometer database user" do
      host "%"
      connection db_settings[:connection]
      username node[:ceilometer][:db][:user]
      password node[:ceilometer][:db][:password]
      provider db_settings[:user_provider]
      action :create
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "grant database access for ceilometer database user" do
      connection db_settings[:connection]
      username node[:ceilometer][:db][:user]
      password node[:ceilometer][:db][:password]
      database_name node[:ceilometer][:db][:database]
      host "%"
      privileges db_settings[:privs]
      provider db_settings[:user_provider]
      require_ssl db_settings[:connection][:ssl][:enabled]
      action :grant
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-ceilometer_database" if ha_enabled
end

case node[:platform_family]
when "suse"
  package "openstack-ceilometer-collector"
  package "openstack-ceilometer-agent-notification"
  package "openstack-ceilometer-api"
when "rhel"
  package "openstack-ceilometer-common"
  package "openstack-ceilometer-collector"
  package "openstack-ceilometer-agent-notification"
  package "openstack-ceilometer-api"
  package "python-ceilometerclient"
else
  package "python-ceilometerclient"
  package "ceilometer-common"
  package "ceilometer-collector"
  package "ceilometer-agent-notification"
  package "ceilometer-api"
end

include_recipe "#{@cookbook_name}::common"

directory "/var/cache/ceilometer" do
  owner node[:ceilometer][:user]
  group "root"
  mode 00755
  action :create
end unless node[:platform_family] == "suse"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
ceilometer_protocol = node[:ceilometer][:api][:protocol]
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node,
                                                       ceilometer_protocol == "https",
                                                       ha_enabled)

crowbar_pacemaker_sync_mark "wait-ceilometer_db_sync" if ha_enabled

execute "ceilometer-dbsync" do
  command "ceilometer-dbsync"
  action :run
  user node[:ceilometer][:user]
  group node[:ceilometer][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:ceilometer][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for ceilometer db_sync" do
  block do
    node.set[:ceilometer][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[ceilometer-dbsync]", :immediately
end

crowbar_pacemaker_sync_mark "create-ceilometer_db_sync" if ha_enabled

use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

service "ceilometer-collector" do
  service_name node[:ceilometer][:collector][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:ceilometer][:config_file])
  subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "ceilometer-collector" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "ceilometer-agent-notification" do
  service_name node[:ceilometer][:agent_notification][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:ceilometer][:config_file])
  subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
end
utils_systemd_service_restart "ceilometer-agent-notification" do
  action use_crowbar_pacemaker_service ? :disable : :enable
end

service "ceilometer-api" do
  service_name node[:ceilometer][:api][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:disable, :stop]
  ignore_failure true
end

if node[:ceilometer][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:ceilometer][:ha][:ports][:api]
else
  bind_host = node[:ceilometer][:api][:host]
  bind_port = node[:ceilometer][:api][:port]
end

if ceilometer_protocol == "https"
  ssl_setup "setting up ssl for ceilometer" do
    generate_certs node[:ceilometer][:ssl][:generate_certs]
    certfile node[:ceilometer][:ssl][:certfile]
    keyfile node[:ceilometer][:ssl][:keyfile]
    group node[:ceilometer][:group]
    fqdn node[:fqdn]
    cert_required node[:ceilometer][:ssl][:cert_required]
    ca_certs node[:ceilometer][:ssl][:ca_certs]
  end
end

crowbar_openstack_wsgi "WSGI entry for ceilometer-api" do
  bind_host bind_host
  bind_port bind_port
  daemon_process "ceilometer-api"
  user node[:ceilometer][:user]
  group node[:ceilometer][:group]
  ssl_enable node[:ceilometer][:api][:protocol] == "https"
  ssl_certfile node[:ceilometer][:ssl][:certfile]
  ssl_keyfile node[:ceilometer][:ssl][:keyfile]
  if node[:ceilometer][:ssl][:cert_required]
    ssl_cacert node[:ceilometer][:ssl][:ca_certs]
  end
  timeout node[:ceilometer][:api][:timeout]
end

apache_site "ceilometer-api.conf" do
  enable true
end

if ha_enabled
  log "HA support for ceilometer is enabled"
  include_recipe "ceilometer::server_ha"
else
  log "HA support for ceilometer is disabled"
end

crowbar_pacemaker_sync_mark "wait-ceilometer_register" if ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       tenant: keystone_settings["admin_tenant"] }

keystone_register "ceilometer wakeup keystone" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  action :wakeup
end

keystone_register "register ceilometer user" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  user_password keystone_settings["service_password"]
  tenant_name keystone_settings["service_tenant"]
  action :add_user
end

keystone_register "give ceilometer user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  tenant_name keystone_settings["service_tenant"]
  role_name "admin"
  action :add_access
end

swift_middlewares = node[:ceilometer][:elements]["ceilometer-swift-proxy-middleware"] || []
unless swift_middlewares.empty?
  keystone_register "give ceilometer user ResellerAdmin role" do
    protocol keystone_settings["protocol"]
    insecure keystone_settings["insecure"]
    host keystone_settings["internal_url_host"]
    port keystone_settings["admin_port"]
    auth register_auth_hash
    user_name keystone_settings["service_user"]
    tenant_name keystone_settings["service_tenant"]
    role_name "ResellerAdmin"
    action :add_access
  end
end

# Create ceilometer service
keystone_register "register ceilometer service" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  service_name "ceilometer"
  service_type "metering"
  service_description "Openstack Telemetry Service"
  action :add_service
end

keystone_register "register ceilometer endpoint" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  endpoint_service "ceilometer"
  endpoint_region keystone_settings["endpoint_region"]
  endpoint_publicURL "#{ceilometer_protocol}://#{my_public_host}:#{node[:ceilometer][:api][:port]}"
  endpoint_adminURL "#{ceilometer_protocol}://#{my_admin_host}:#{node[:ceilometer][:api][:port]}"
  endpoint_internalURL "#{ceilometer_protocol}://#{my_admin_host}:#{node[:ceilometer][:api][:port]}"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

# In stoney/icehouse we have the cronjob crowbar-ceilometer-expirer in
# /etc/cron.daily/.  In tex/juno this cronjob is moved into the
# package, and is renamed as openstack-ceilometer-expirer.  We remove
# the old cronjob here.
file "/etc/cron.daily/crowbar-ceilometer-expirer" do
  action :delete
end

# Cronjob to repair the database and free space for mongodb.  This
# only makes sense when the metering_time_to_live or
# event_time_to_leave > 0
time_to_live_set = node[:ceilometer][:database][:metering_time_to_live] > 0 \
                   || node[:ceilometer][:database][:event_time_to_live] > 0
if node[:ceilometer][:use_mongodb] && time_to_live_set
  template "/etc/cron.weekly/crowbar-repairdatabase-mongodb" do
    source "cronjob-repairdatabase-mongodb.erb"
    owner "root"
    group "root"
    mode 0755
    backup false
    variables(
      listen_addr: Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    )
  end
else
  file "/etc/cron.weekly/crowbar-repairdatabase-mongodb" do
    action :delete
  end
end

crowbar_pacemaker_sync_mark "create-ceilometer_register" if ha_enabled
