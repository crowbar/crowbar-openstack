#
# Cookbook Name:: glance
# Recipe:: registry
#
#

include_recipe "#{@cookbook_name}::common"

package "glance-registry" do
  package_name "openstack-glance-registry" if ["rhel", "suse"].include?(node[:platform_family])
end

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
network_settings = GlanceHelper.network_settings(node)

ha_enabled = node[:glance][:ha][:enabled]
memcached_servers = MemcachedHelper.get_memcached_servers(
  ha_enabled ? CrowbarPacemakerHelper.cluster_nodes(node, "glance-server") : [node]
)

memcached_instance("glance")

template node[:glance][:manage][:config_file] do
  source "glance-manage.conf.erb"
  owner "root"
  group node[:glance][:group]
  mode 0640
end

template node[:glance][:registry][:config_file] do
  source "glance-registry.conf.erb"
  owner "root"
  group node[:glance][:group]
  mode 0640
  variables(
      bind_host: network_settings[:registry][:bind_host],
      bind_port: network_settings[:registry][:bind_port],
      keystone_settings: keystone_settings,
      memcached_servers: memcached_servers,
      rabbit_settings: fetch_rabbitmq_settings
  )
end

ha_enabled = node[:glance][:ha][:enabled]
is_founder = CrowbarPacemakerHelper.is_cluster_founder?(node)

crowbar_pacemaker_sync_mark "wait-glance_database" if ha_enabled

execute "glance-manage db sync" do
  user node[:glance][:user]
  group node[:glance][:group]
  command "glance-manage db sync"
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:glance][:db_synced] && (!ha_enabled || is_founder) }
end

execute "glance-manage db_load_metadefs" do
  user node[:glance][:user]
  group node[:glance][:group]
  command "glance-manage db_load_metadefs"
  # We only load the metadefs the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:glance][:db_synced] && (!ha_enabled || is_founder) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for glance db_sync" do
  block do
    node.set[:glance][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[glance-manage db_load_metadefs]", :immediately
end

crowbar_pacemaker_sync_mark "create-glance_database" if ha_enabled

glance_service "registry"
