# database creation for manila

ha_enabled = node[:manila][:ha][:enabled]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-manila_database" if ha_enabled

# Create the Manila Database
database "create #{node[:manila][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:manila][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create manila database user" do
  host "%"
  connection db_settings[:connection]
  username node[:manila][:db][:user]
  password node[:manila][:db][:password]
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for manila database user" do
  connection db_settings[:connection]
  username node[:manila][:db][:user]
  password node[:manila][:db][:password]
  database_name node[:manila][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

execute "manila-manage db sync" do
  command "manila-manage db sync"
  user node[:manila][:user]
  group node[:manila][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:manila][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for manila db_sync" do
  block do
    node.set[:manila][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[manila-manage db sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-manila_database" if ha_enabled
