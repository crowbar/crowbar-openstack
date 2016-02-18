# database creation for congress

ha_enabled = node[:congress][:ha][:enabled]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-congress_database"

# Create the Congress Database
database "create #{node[:congress][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:congress][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create congress database user" do
  host "%"
  connection db_settings[:connection]
  username node[:congress][:db][:user]
  password node[:congress][:db][:password]
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for congress database user" do
  connection db_settings[:connection]
  username node[:congress][:db][:user]
  password node[:congress][:db][:password]
  database_name node[:congress][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

execute "congress-manage db sync" do
  command "congress-db-manage sync"
  user node[:congress][:user]
  group node[:congress][:group]
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:congress][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for congress db_sync" do
  block do
    node[:congress][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[congress-manage db sync]", :immediately
end

crowbar_pacemaker_sync_mark "create-congress_database"
