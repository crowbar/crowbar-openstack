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

package "keystone" do
  package_name "openstack-keystone" if %w(rhel suse).include?(node[:platform_family])
end

if %w(rhel).include?(node[:platform_family])
  #pastedeploy is not installed properly by yum, here is workaround
  bash "fix_broken_pastedeploy" do
    not_if "echo 'from paste import deploy' | python -"
    code <<-EOH
      paste_dir=`echo 'import paste; print paste.__path__[0]' | python -`
      ln -s ${paste_dir}/../PasteDeploy*/paste/deploy ${paste_dir}/
    EOH
  end
end

# useful with .openrc
package "python-openstackclient"

# FIXME(gyee): need a more elegant way to update the default auth methods
# if these happened to change from one release to another.
auth_methods = "password,token,oauth1,mapped,application_credential"

ha_enabled = node[:keystone][:ha][:enabled]

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if ha_enabled
  log "HA support for keystone is enabled"
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_admin_host = admin_address
  bind_admin_port = node[:keystone][:ha][:ports][:admin_port]
  bind_service_host = admin_address
  bind_service_port = node[:keystone][:ha][:ports][:service_port]
else
  log "HA support for keystone is disabled"
  bind_admin_host = node[:keystone][:api][:admin_host]
  bind_admin_port = node[:keystone][:api][:admin_port]
  bind_service_host = node[:keystone][:api][:api_host]
  bind_service_port = node[:keystone][:api][:service_port]
end

# verify the OpenID Connect Federation parameters
openidc_enabled = node[:keystone][:federation][:openidc][:enabled]
openidc_provider = node[:keystone][:federation][:openidc][:identity_provider]
openidc_response_type = node[:keystone][:federation][:openidc][:response_type]
openidc_scope = node[:keystone][:federation][:openidc][:scope]
openidc_metadata_url = node[:keystone][:federation][:openidc][:metadata_url]
openidc_client_id = node[:keystone][:federation][:openidc][:client_id]
openidc_client_secret = node[:keystone][:federation][:openidc][:client_secret]
openidc_passphrase = node[:keystone][:federation][:openidc][:passphrase]
openidc_redirect_uri = node[:keystone][:federation][:openidc][:redirect_uri]

openidc_attributes = {
  "openidc_response_type" => openidc_response_type,
  "openidc_scope" => openidc_scope,
  "openidc_metadata_url" => openidc_metadata_url,
  "openidc_client_id" => openidc_client_id,
  "openidc_client_secret" => openidc_client_secret,
  "openidc_passphrase" => openidc_passphrase,
  "openidc_provider" => openidc_provider
}

if openidc_enabled
  auth_methods = "#{auth_methods},openid"
  openidc_attributes.each do |openidc_attr_name, openidc_attr_value|
    raise "#{openidc_attr_name} is required and cannot be an empty value" if
        openidc_attr_value.empty?
  end
end

# Ideally this would be called admin_host, but that's already being
# misleadingly used to store a value which actually represents the
# service bind address.
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:keystone][:api][:protocol] == "https", ha_enabled)
# can't use CrowbarPacemakerHelper.cluster_nodes() here as it will sometimes not return
# nodes which will be added to the cluster in current chef-client run.
cluster_nodes = ha_enabled ? node[:pacemaker][:elements]["pacemaker-cluster-member"] : []
cluster_nodes = cluster_nodes.map { |n| Chef::Node.load(n) }
cluster_nodes.sort_by! { |n| n[:hostname] }

memcached_instance "keystone"

# resource to set a flag when apache2 is restarted so we now which cookbook was the
# one that triggered the restart, in order to know if the restart is allowed
ruby_block "set origin for apache2 restart" do
  block do
    node.run_state["apache2_restart_origin"] = @cookbook_name
  end
  action :nothing
end

if node[:keystone][:api][:protocol] == "https"
  ssl_setup "setting up ssl for keystone" do
    generate_certs node[:keystone][:ssl][:generate_certs]
    certfile node[:keystone][:ssl][:certfile]
    keyfile node[:keystone][:ssl][:keyfile]
    group node[:keystone][:group]
    fqdn node[:fqdn]
    alt_names ["DNS:#{my_admin_host}", "DNS:#{my_public_host}"]
    cert_required !node[:keystone][:ssl][:insecure]
    ca_certs node[:keystone][:ssl][:ca_certs]
  end
end

if node[:keystone][:frontend] == "uwsgi"

  service "keystone" do
    service_name node[:keystone][:service_name]
    supports status: true, restart: true
    action [:disable, :stop]
  end

  directory "/usr/lib/cgi-bin/keystone/" do
    owner "root"
    group "root"
    mode 0755
    action :create
    recursive true
  end

  template "/usr/lib/cgi-bin/keystone/application.py" do
    source "keystone-uwsgi.py.erb"
    mode 0755
  end

  uwsgi "keystone" do
    options({
      chdir: "/usr/lib/cgi-bin/keystone/",
      callable: :application,
      module: :application,
      user: node[:keystone][:user],
      log: "/var/log/keystone/keystone.log"
    })
    instances ([
      {socket: "#{bind_service_host}:#{bind_service_port}", env: "name=main"},
      {socket: "#{bind_admin_host}:#{bind_admin_port}", env: "name=admin"}
    ])
    service_name "keystone-uwsgi"
  end

  service "keystone-uwsgi" do
    supports status: true, restart: true, start: true
    action :start
    subscribes :restart, "template[/usr/lib/cgi-bin/keystone/application.py]", :immediately
  end

elsif node[:keystone][:frontend] == "apache"
  keystone_enabled = !node[:keystone][:disable_vhost]

  service "keystone" do
    service_name node[:keystone][:service_name]
    supports status: true, restart: true
    action [:disable, :stop]
    # allow to fail here because there may not be a service "keystone"
    ignore_failure true
  end

  # automagically populate the redirect_uri if user does not specify one
  if openidc_redirect_uri.empty?
    openidc_redirect_uri = ::File.join(
      keystone_settings["websso_keystone_url"],
      "/OS-FEDERATION/identity_providers/#{openidc_provider}/protocols/openid/auth"
    )
  end

  package "apache2-mod_auth_openidc" if openidc_enabled
  apache_module "auth_openidc" if openidc_enabled

  crowbar_openstack_wsgi "WSGI entry for keystone-public" do
    bind_host bind_service_host
    bind_port bind_service_port
    daemon_process "keystone-public"
    user node[:keystone][:user]
    group node[:keystone][:group]
    script_alias "/usr/bin/keystone-wsgi-public"
    pass_authorization true
    limit_request_body 114688
    processes node[:keystone][:api][:processes]
    threads node[:keystone][:api][:threads]
    ssl_enable node[:keystone][:api][:protocol] == "https"
    ssl_certfile node[:keystone][:ssl][:certfile]
    ssl_keyfile node[:keystone][:ssl][:keyfile]
    ssl_cacert node[:keystone][:ssl][:ca_certs] unless node[:keystone][:ssl][:insecure]
    # LDAP backend can be slow..
    timeout 600
    # auth_openidc configuration
    openidc_enabled openidc_enabled
    openidc_provider openidc_provider
    openidc_response_type openidc_response_type
    openidc_scope openidc_scope
    openidc_metadata_url openidc_metadata_url
    openidc_client_id openidc_client_id
    openidc_client_secret openidc_client_secret
    openidc_passphrase openidc_passphrase
    openidc_redirect_uri openidc_redirect_uri
  end

  apache_site "keystone-public.conf" do
    enable keystone_enabled
  end

  crowbar_openstack_wsgi "WSGI entry for keystone-admin" do
    bind_host bind_admin_host
    bind_port bind_admin_port
    daemon_process "keystone-admin"
    user node[:keystone][:user]
    group node[:keystone][:group]
    script_alias "/usr/bin/keystone-wsgi-admin"
    pass_authorization true
    limit_request_body 114688
    processes node[:keystone][:api][:processes]
    threads node[:keystone][:api][:threads]
    ssl_enable node[:keystone][:api][:protocol] == "https"
    ssl_certfile node[:keystone][:ssl][:certfile]
    ssl_keyfile node[:keystone][:ssl][:keyfile]
    ssl_cacert node[:keystone][:ssl][:ca_certs] unless node[:keystone][:ssl][:insecure]
    # LDAP backend can be slow..
    timeout 600
    # auth_openidc configuration
    openidc_enabled openidc_enabled
    openidc_provider openidc_provider
    openidc_response_type openidc_response_type
    openidc_scope openidc_scope
    openidc_metadata_url openidc_metadata_url
    openidc_client_id openidc_client_id
    openidc_client_secret openidc_client_secret
    openidc_passphrase openidc_passphrase
    openidc_redirect_uri openidc_redirect_uri
  end

  apache_site "keystone-admin.conf" do
    enable keystone_enabled
  end
end

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-keystone_database" if ha_enabled

# Create the Keystone Database
database "create #{node[:keystone][:db][:database]} database" do
    connection db_settings[:connection]
    database_name node[:keystone][:db][:database]
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create keystone database user" do
    connection db_settings[:connection]
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    host "%"
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for keystone database user" do
    connection db_settings[:connection]
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    database_name node[:keystone][:db][:database]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    require_ssl db_settings[:connection][:ssl][:enabled]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-keystone_database" if ha_enabled

sql_connection = fetch_database_connection_string(node[:keystone][:db])

# we have to calculate max_active_keys for fernet token provider
# http://docs.openstack.org/admin-guide/identity-fernet-token-faq.html# \
#       i-rotated-keys-and-now-tokens-are-invalidating-early-what-did-i-do
# max_active_keys = (token_expiration / rotation_frequency) + 2
# keystone fernet_rotate job runs hourly, it means that rotation_frequency = 1
# node[:keystone][:token_expiration] is in seconds and has to be encoded to hours
max_active_keys = (node[:keystone][:token_expiration].to_f / 3600).ceil + 2

# cron.hourly runs at a different time offset on every node in the cluster,
# so in the worst case we have #nodes rotates (if we're unlucky and
# the keystone-fernet-token provider is moving around quickly
max_active_keys += cluster_nodes.length if ha_enabled

register_auth_hash = { user: node[:keystone][:admin][:username],
                       password: node[:keystone][:admin][:password],
                       project: node[:keystone][:admin][:project] }

profiler_settings = KeystoneHelper.profiler_settings(node, @cookbook_name)

template node[:keystone][:config_file] do
    source "keystone.conf.erb"
    owner "root"
    group node[:keystone][:group]
    mode 0640
    variables(
      sql_connection: sql_connection,
      sql_idle_timeout: node[:keystone][:sql][:idle_timeout],
      debug: node[:keystone][:debug],
      insecure_debug: node[:keystone][:insecure_debug],
      admin_endpoint: KeystoneHelper.service_URL(
        node[:keystone][:api][:protocol],
        my_admin_host, node[:keystone][:api][:admin_port]
      ),
      memcached_servers: MemcachedHelper.get_memcached_servers(node, cluster_nodes),
      token_format: node[:keystone][:token_format],
      token_expiration: node[:keystone][:token_expiration],
      max_active_keys: max_active_keys,
      protocol: node[:keystone][:api][:protocol],
      frontend: node[:keystone][:frontend],
      rabbit_settings: fetch_rabbitmq_settings,
      profiler_settings: profiler_settings,
      websso_enabled: keystone_settings["websso_enabled"],
      trusted_dashboards: keystone_settings["trusted_dashboards"],
      auth_methods: auth_methods,
      openidc_enabled: openidc_enabled
    )
    if node[:keystone][:frontend] == "apache"
      notifies :create, resources(ruby_block: "set origin for apache2 restart"), :immediately
      notifies :restart, resources(service: "apache2"), :immediately
    elsif node[:keystone][:frontend] == "uwsgi"
      notifies :restart, resources(service: "keystone-uwsgi"), :immediately
    end
end

if %w(rhel).include?(node[:platform_family])
  # Permissions for /etc/keystone are wrong in the RDO repo
  directory "/etc/keystone" do
    action :create
    owner "root"
    group node[:keystone][:group]
    mode 0750
  end
end

directory node[:keystone][:domain_config_dir] do
  action :create
  owner "root"
  group node[:keystone][:group]
  mode 0750
  only_if { node[:keystone][:domain_specific_drivers] }
end

if node[:keystone][:domain_specific_drivers]
  node[:keystone][:domain_specific_config].keys.each do |domain|
    template "#{node[:keystone][:domain_config_dir]}/keystone.#{domain}.conf" do
      source "keystone.domain.conf.erb"
      owner "root"
      group node[:keystone][:group]
      mode 0o0640
      variables(
        domain: domain
      )
      if node[:keystone][:frontend] == "apache"
        notifies :create, resources(ruby_block: "set origin for apache2 restart"), :immediately
        notifies :restart, resources(service: "apache2"), :immediately
      elsif node[:keystone][:frontend] == "uwsgi"
        notifies :restart, resources(service: "keystone-uwsgi"), :immediately
      end
    end
  end
end

crowbar_pacemaker_sync_mark "wait-keystone_db_sync" if ha_enabled

execute "keystone-manage db_sync" do
  command "keystone-manage db_sync"
  user node[:keystone][:user]
  group node[:keystone][:group]
  action :run
  # We only do the sync the first time, and only if we're not doing HA or if we
  # are the founder of the HA cluster (so that it's really only done once).
  only_if { !node[:keystone][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

# We want to keep a note that we've done db_sync, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for keystone db_sync" do
  block do
    node.set[:keystone][:db_synced] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[keystone-manage db_sync]", :immediately
end

if ha_enabled
  crowbar_pacemaker_sync_mark "create-keystone_db_sync"
end

# Configure Keystone token fernet backend provider (non-HA case)
if !ha_enabled && node[:keystone][:token_format] == "fernet"
  # Rotate primary key, which is used for new tokens
  keystone_fernet "keystone-fernet-rotate-non-ha" do
    action :rotate_script
  end

  link "/etc/cron.hourly/openstack-keystone-fernet" do
    to "/var/lib/keystone/keystone-fernet-rotate"
  end

  unless File.exist?("/etc/keystone/fernet-keys/0")
    # Setup a key repository for fernet tokens
    keystone_fernet "keystone-fernet-setup-non-ha" do
      action :setup
    end
  end
end

# This also includes fernet setup for HA case.
include_recipe "keystone::ha" if ha_enabled

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required services correctly configured and running before we create
# the keystone resources
crowbar_pacemaker_sync_mark "sync-keystone_before_register" if ha_enabled

crowbar_pacemaker_sync_mark "wait-keystone_register" do
  # keystone_register might be slow
  timeout 150
  only_if { ha_enabled }
end

keystone_insecure = node["keystone"]["api"]["protocol"] == "https" && node[:keystone][:ssl][:insecure]

register_auth_hash = { user: node[:keystone][:admin][:username],
                       password: node[:keystone][:admin][:password],
                       project: node[:keystone][:admin][:project] }

old_password = node[:keystone][:admin][:old_password]
old_register_auth_hash = register_auth_hash.clone
old_register_auth_hash[:password] = old_password
update_admin_password = node[:keystone][:bootstrap] &&
  (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) &&
  old_password && !old_password.empty? &&
  old_password != node[:keystone][:admin][:password]

keystone_register "update admin password" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  auth old_register_auth_hash
  user_name node[:keystone][:admin][:username]
  user_password node[:keystone][:admin][:password]
  project_name node[:keystone][:admin][:project]
  action :add_user
  only_if { update_admin_password }
end

ruby_block "backup current admin password on node attributes" do
  block do
    node.set[:keystone][:admin][:old_password] = node[:keystone][:admin][:password]
    node.save
  end
end

# Creates admin user, admin role and admin project
execute "keystone-manage bootstrap" do
  command "keystone-manage bootstrap \
  --bootstrap-password #{node[:keystone][:admin][:password]} \
  --bootstrap-username #{node[:keystone][:admin][:username]} \
  --bootstrap-project-name #{node[:keystone][:admin][:project]} \
  --bootstrap-role-name admin \
  --bootstrap-service-name keystone \
  --bootstrap-region-id #{node[:keystone][:api][:region]} \
  --bootstrap-admin-url #{KeystoneHelper.admin_auth_url(node, my_admin_host)} \
  --bootstrap-public-url #{KeystoneHelper.public_auth_url(node, my_public_host)} \
  --bootstrap-internal-url #{KeystoneHelper.internal_auth_url(node, my_admin_host)}"
  action :run
  only_if do
    !node[:keystone][:bootstrap] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node))
  end
end

# Silly wake-up call - this is a hack; we use retries because the server was
# just (re)started, and might not answer on the first try
keystone_register "wakeup keystone" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  auth register_auth_hash
  retries 5
  retry_delay 10
  reissue_token_on_error true
  action :wakeup
end

# We want to keep a note that we've done bootstrap, so we don't do it again.
# If we were doing that outside a ruby_block, we would add the note in the
# compile phase, before the actual db_sync is done (which is wrong, since it
# could possibly not be reached in case of errors).
ruby_block "mark node for keystone bootstrap" do
  block do
    node.set[:keystone][:bootstrap] = true
    node.save
  end
  action :nothing
  subscribes :create, "execute[keystone-manage bootstrap]", :immediately
end

[:service, :default].each do |project_type|
  project = node[:keystone][project_type][:project]

  keystone_register "add default #{project} project" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    auth register_auth_hash
    project_name project
    action :add_project
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

if node[:keystone][:domain_specific_drivers]
  node[:keystone][:domain_specific_config].keys.each do |domain|
    keystone_register "add default #{domain} domain" do
      protocol node[:keystone][:api][:protocol]
      insecure keystone_insecure
      host my_admin_host
      port node[:keystone][:api][:admin_port]
      auth register_auth_hash
      domain_name domain
      action :add_domain
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end
end

# Create default role admin for admin user in default domain
keystone_register "add default admin role for domain default" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  auth register_auth_hash
  user_name node[:keystone][:admin][:username]
  role_name "admin"
  domain_name "Default"
  action :add_domain_role
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Create default user
if node[:keystone][:default][:create_user]
  keystone_register "add default #{node[:keystone][:default][:username]} user" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    auth register_auth_hash
    user_name node[:keystone][:default][:username]
    user_password node[:keystone][:default][:password]
    project_name node[:keystone][:default][:project]
    action :add_user
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

# Create member role used by horizon (see OPENSTACK_KEYSTONE_DEFAULT_ROLE option)
### Remove after Rocky is required (keystone-bootstrap creates it for us)
keystone_register "add default member role" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  auth register_auth_hash
  role_name "member"
  action :add_role
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Create Access info
user_roles = [
  [node[:keystone][:admin][:username], "admin", node[:keystone][:admin][:project]],
  [node[:keystone][:admin][:username], "admin", node[:keystone][:default][:project]]
]
if node[:keystone][:default][:create_user]
  user_roles << [node[:keystone][:default][:username],
                 "member",
                 node[:keystone][:default][:project]]
end
user_roles.each do |args|
  keystone_register "add default #{args[2]}:#{args[0]} -> #{args[1]} role" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    auth register_auth_hash
    user_name args[0]
    role_name args[1]
    project_name args[2]
    action :add_access
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

# Create EC2 creds for our users
ec2_creds = [
  [node[:keystone][:admin][:username], node[:keystone][:admin][:project]],
  [node[:keystone][:admin][:username], node[:keystone][:default][:project]]
]
if node[:keystone][:default][:create_user]
  ec2_creds << [node[:keystone][:default][:username], node[:keystone][:default][:project]]
end
ec2_creds.each do |args|
  keystone_register "add default ec2 creds for #{args[1]}:#{args[0]}" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    auth register_auth_hash
    port node[:keystone][:api][:admin_port]
    user_name args[0]
    project_name args[1]
    action :add_ec2
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

crowbar_pacemaker_sync_mark "create-keystone_register" if ha_enabled

include_recipe "keystone::update_endpoint"

template "/root/.openrc" do
  source "openrc.erb"
  owner "root"
  group "root"
  mode 0600
  variables(
    keystone_settings: keystone_settings
    )
end

# Set new endpoint URL.
internal_url_host = keystone_settings["internal_url_host"]
if node[:keystone][:api][:internal_url_host] != internal_url_host
  node.set[:keystone][:api][:internal_url_host] = internal_url_host
  node.save
end
Chef::Log.debug("setting new endpoint host to " \
                "#{node[:keystone][:api][:internal_url_host]}")

if node[:keystone][:resource_limits] && \
    node[:keystone][:resource_limits].include?("apache2") && \
    node[:keystone][:resource_limits]["apache2"].values.any?
  ruby_block "set global apache limits" do
    block do
      # Get the limits set in the proposal
      keystone_apache_limits = node[:keystone][:resource_limits]["apache2"]

      # If this value hasn't been set in this chef run, make it a hash
      node.default[:resource_limits] = {} unless node[:resource_limits]

      # If apache limits have already been set in this chef run, get those
      global_apache_limits = node[:resource_limits]["apache2"] || {}
      global_apache_limits = global_apache_limits.to_hash

      # For each limit setting, get the maximum across all barclamps seen so far
      keystone_apache_limits.each do |name, value|
        global_apache_limits[name] = [global_apache_limits[name].to_i, value].max
      end

      # Set the new limits in the node so it can be re-used in this chef run.
      # node.default is cleared before every chef run so this will not pollute the node.
      node.default[:resource_limits]["apache2"] = global_apache_limits

      # Now that the limits variable is set, override the lwrp parameter at compile time
      rsc_name = "Resource limits for apache2"
      override_rsc = Chef::Resource::UtilsSystemdOverrideLimits.new(rsc_name, run_context)
      override_rsc.service_name "apache2"
      override_rsc.limits node[:resource_limits]["apache2"]
      override_rsc.run_action :create
    end
  end
# If we've deleted limits across the board, delete leftover override files (and don't create them)
elsif !node[:resource_limits] || !node[:resource_limits]["apache2"] || \
    (node[:resource_limits]["apache2"] || {}).to_hash.values.none?
  utils_systemd_override_limits "Resource limits for apache2" do
    service_name "apache2"
    action :delete
  end
end
