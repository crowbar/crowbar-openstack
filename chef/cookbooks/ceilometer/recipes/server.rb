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

monasca_server = node_search_with_cache("roles:monasca-server").first
if monasca_server.nil?
  Chef::Log.warn("No monasca-server found. Skip Ceilometer setup.")
  return
end

ha_enabled = node[:ceilometer][:ha][:server][:enabled]

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

case node[:platform_family]
when "suse"
  package "openstack-monasca-ceilometer-agent-notification"
when "rhel"
  package "openstack-ceilometer-common"
  package "openstack-ceilometer-agent-notification"
  package "python-ceilometerclient"
else
  package "python-ceilometerclient"
  package "ceilometer-common"
  package "ceilometer-agent-notification"
end

include_recipe "#{@cookbook_name}::common"

directory "/var/cache/ceilometer" do
  owner node[:ceilometer][:user]
  group "root"
  mode 00755
  action :create
end unless node[:platform_family] == "suse"

cookbook_file node[:ceilometer][:monasca][:field_definitions] do
  source "monasca-field-definitions.yaml"
  owner "root"
  group node[:ceilometer][:group]
  mode "0640"
  notifies :restart, resources(service: "apache2")
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
monasca_project = monasca_server[:monasca][:service_tenant]

crowbar_pacemaker_sync_mark "wait-ceilometer_register" if ha_enabled

register_auth_hash = { user: keystone_settings["admin_user"],
                       password: keystone_settings["admin_password"],
                       project: keystone_settings["admin_project"] }

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
  project_name monasca_project
  action :add_user
end

keystone_register "give ceilometer user access" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  project_name monasca_project
  role_name "admin"
  action :add_access
end

keystone_register "grant ceilometer user monasca-user role on monasca projec" do
  protocol keystone_settings["protocol"]
  insecure keystone_settings["insecure"]
  host keystone_settings["internal_url_host"]
  port keystone_settings["admin_port"]
  auth register_auth_hash
  user_name keystone_settings["service_user"]
  project_name monasca_project
  role_name "monasca-user"
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
    project_name monasca_project
    role_name "ResellerAdmin"
    action :add_access
  end
end

crowbar_pacemaker_sync_mark "create-ceilometer_register" if ha_enabled

crowbar_pacemaker_sync_mark "wait-ceilometer_upgrade" if ha_enabled

execute "ceilometer-upgrade" do
  # --skip-gnocchi-resource-types is needed because gnocchi is not deployed.
  # if the flag is not given, ceilometer-upgrade returns with 1 and chef-client fails
  command "ceilometer-upgrade --skip-gnocchi-resource-types"
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
  subscribes :create, "execute[ceilometer-upgrade]", :immediately
end

crowbar_pacemaker_sync_mark "create-ceilometer_upgrade" if ha_enabled

service "ceilometer-agent-notification" do
  service_name node[:ceilometer][:agent_notification][:service_name]
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
  subscribes :restart, resources(template: node[:ceilometer][:config_file])
  subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  subscribes :restart, resources("template[/etc/ceilometer/event_pipeline.yaml]")
end
utils_systemd_service_restart "ceilometer-agent-notification" do
  action :enable
end

# In stoney/icehouse we have the cronjob crowbar-ceilometer-expirer in
# /etc/cron.daily/.  In tex/juno this cronjob is moved into the
# package, and is renamed as openstack-ceilometer-expirer.  We remove
# the old cronjob here.
file "/etc/cron.daily/crowbar-ceilometer-expirer" do
  action :delete
end

file "/etc/cron.weekly/crowbar-repairdatabase-mongodb" do
  action :delete
end
