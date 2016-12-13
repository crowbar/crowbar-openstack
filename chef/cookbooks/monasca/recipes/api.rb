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

apache_module "deflate" do
  conf false
  enable true
end

apache_site "000-default" do
  enable false
end

### TODO: uncomment this once there is a package.
# package "openstack-monasca-api"

### FIXME: remove this once there is a package creating this directory

directory "/etc/monasca/" do
  owner "root"
  group "root"
  mode 0o755
  recursive true
  notifies :create, "template[/etc/monasca/api-config.conf]"
end

ha_enabled = node[:monasca][:ha][:enabled]

db_settings = fetch_database_settings
db_conn_scheme = db_settings[:url_scheme]

db_settings[:backend_name] == "mysql" && db_conn_scheme = "mysql+pymysql"

database_connection = "#{db_conn_scheme}://" \
  "#{node[:monasca][:db][:user]}" \
  ":#{node[:monasca][:db][:password]}" \
  "@#{db_settings[:address]}" \
  "/#{node[:monasca][:db][:database]}"

crowbar_pacemaker_sync_mark "wait-monasca_database"

# Create the Monasca Database
database "create #{node[:monasca][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:monasca][:db][:database]
  provider db_settings[:provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:monasca][:db][:database]
  username node[:monasca][:db][:user]
  password node[:monasca][:db][:password]
  host "%"
  provider db_settings[:user_provider]
  action :create
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for #{@cookbook_name} database user" do
  connection db_settings[:connection]
  database_name node[:monasca][:db][:database]
  username node[:monasca][:db][:user]
  password node[:monasca][:db][:password]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

### FIXME: uncomment this once we have a package that contains a monasca-manage
### command.
# execute "monasca-manage db upgrade" do
#   user node[:monasca][:user]
#   group node[:monasca][:group]
#   command "monasca-manage db upgrade -d #{database_connection} -v head "
#   # We only do the sync the first time, and only if we're not doing HA or if we
#   # are the founder of the HA cluster (so that it's really only done once).
#   only_if do
#     !node[:monasca][:db_synced] &&
#       (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
#   end
# end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for monasca db_sync" do
  block do
    node.set[:monasca][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[monasca-manage db upgrade]", :immediately
end

crowbar_pacemaker_sync_mark "create-monasca_database"

template "/etc/monasca/api-config.conf" do
  source "api-config.conf.erb"
  owner "root"
  ### FIXME: Uncomment once we have a package that creates a monasca group
  # group node[:monasca][:group]
  mode 0o0640
  variables(
    database_connection: database_connection,
    keystone_settings: KeystoneHelper.keystone_settings(node, @cookbook_name)
  )
  notifies :reload, resources(service: "apache2")
end

### FIXME: Uncomment once we actually have a runnable WSGI app from a
###        monasca-api package
# crowbar_openstack_wsgi "WSGI entry for monasca-api" do
#   bind_host bind_host
#   bind_port bind_port
#   daemon_process "monasca-api"
#   user node[:monasca][:user]
#   group node[:monasca][:group]
#   processes node[:monasca][:api][:processes]
#   threads node[:monasca][:api][:threads]
# end
#
# apache_site "monasca-api.conf" do
#   enable true
# end

node.save
