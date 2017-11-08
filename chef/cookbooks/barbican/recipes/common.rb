#
# Copyright 2016 SUSE Linux GmbH
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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"

package "openstack-barbican"

ha_enabled = node[:barbican][:ha][:enabled]

db_settings = fetch_database_settings

barbican_protocol = node[:barbican][:api][:protocol]

public_host = CrowbarHelper.get_host_for_public_url(node,
                                                    barbican_protocol == "https",
                                                    node[:barbican][:ha][:enabled])

database_connection = fetch_database_connection_string(node[:barbican][:db])

template node[:barbican][:config_file] do
  source "barbican.conf.erb"
  owner "root"
  group node[:barbican][:group]
  mode 0o640
  variables(
    database_connection: database_connection,
    kek: node[:barbican][:kek],
    keystone_listener: node[:barbican][:enable_keystone_listener],
    host_href: "#{barbican_protocol}://#{public_host}:#{node[:barbican][:api][:bind_port]}",
    rabbit_settings: fetch_rabbitmq_settings,
    keystone_settings: KeystoneHelper.keystone_settings(node, @cookbook_name)
  )
  notifies :reload, resources(service: "apache2")
end

crowbar_pacemaker_sync_mark "wait-barbican_database" if ha_enabled

# Create the Barbican Database
database "create #{node[:barbican][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:barbican][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:barbican][:db][:database]
  username node[:barbican][:db][:user]
  password node[:barbican][:db][:password]
  host "%"
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:barbican][:db][:database]
  username node[:barbican][:db][:user]
  password node[:barbican][:db][:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  require_ssl db_settings[:connection][:ssl][:enabled]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

execute "barbican-manage db upgrade" do
  user node[:barbican][:user]
  group node[:barbican][:group]
  command "barbican-manage db upgrade -v head"
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if do
    !node[:barbican][:db_synced] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for barbican db_sync" do
  block do
    node.set[:barbican][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[barbican-manage db upgrade]", :immediately
end

crowbar_pacemaker_sync_mark "create-barbican_database" if ha_enabled
