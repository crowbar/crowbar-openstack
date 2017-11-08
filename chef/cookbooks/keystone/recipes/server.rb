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

ha_enabled = node[:keystone][:ha][:enabled]

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

node.normal[:apache][:listen_ports_crowbar] ||= {}
node.normal[:apache][:listen_ports_crowbar][:keystone] = { admin: [bind_admin_port], service: [bind_service_port] }

# Ideally this would be called admin_host, but that's already being
# misleadingly used to store a value which actually represents the
# service bind address.
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:keystone][:api][:protocol] == "https", ha_enabled)

# Other barclamps need to know the hostname to reach keystone
if node[:keystone][:api][:internal_URL_host] != my_admin_host
  node.set[:keystone][:api][:internal_URL_host] = my_admin_host
  node.save
end

# resource to set a flag when apache2 is restarted so we now which cookbook was the
# one that triggered the restart, in order to know if the restart is allowed
ruby_block "set origin for apache2 restart" do
  block do
    node.run_state["apache2_restart_origin"] = @cookbook_name
  end
  action :nothing
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

  service "keystone" do
    service_name node[:keystone][:service_name]
    supports status: true, restart: true
    action [:disable, :stop]
    # allow to fail here because there may not be a service "keystone"
    ignore_failure true
  end

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
    ssl_cacert node[:keystone][:ssl][:ca_certs]
  end

  apache_site "keystone-public.conf" do
    enable true
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
    ssl_cacert node[:keystone][:ssl][:ca_certs]
  end

  apache_site "keystone-admin.conf" do
    enable true
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

if ha_enabled
  memcached_nodes = CrowbarPacemakerHelper.cluster_nodes(node, "keystone-server")
  memcached_servers = memcached_nodes.map do |n|
    node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
    "#{node_admin_ip}:#{n[:memcached][:port]}"
  end
else
  node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  memcached_servers = ["#{node_admin_ip}:#{node[:memcached][:port]}"]
end
memcached_servers.sort!

# we have to calculate max_active_keys for fernet token provider
# http://docs.openstack.org/admin-guide/identity-fernet-token-faq.html# \
#       i-rotated-keys-and-now-tokens-are-invalidating-early-what-did-i-do
# max_active_keys = (token_expiration / rotation_frequency) + 2
# keystone fernet_rotate job runs hourly, it means that rotation_frequency = 1
# node[:keystone][:token_expiration] is in seconds and has to be encoded to hours
max_active_keys = (node[:keystone][:token_expiration].to_f / 3600).ceil + 2

register_auth_hash = { user: node[:keystone][:admin][:username],
                       password: node[:keystone][:admin][:password],
                       tenant: node[:keystone][:admin][:tenant] }

if node[:keystone].key?(:endpoint)
  endpoint_protocol = node[:keystone][:endpoint][:protocol]
  endpoint_insecure = node[:keystone][:endpoint][:insecure]
  # In order to update keystone's endpoints we need the old internal endpoint.
  endpoint_port = node[:keystone][:endpoint][:port]
else
  endpoint_protocol = node[:keystone][:api][:protocol]
  endpoint_insecure = node[:keystone][:ssl][:insecure]
  endpoint_port = node[:keystone][:api][:admin_port]
end

endpoint_host = my_admin_host

# Update keystone endpoints (in case we switch http/https this will update the
# endpoints to the correct ones). This needs to be done _before_ we switch
# protocols on the keystone api.
keystone_register "update keystone endpoint" do
  protocol endpoint_protocol
  insecure endpoint_insecure
  host endpoint_host
  port endpoint_port
  auth register_auth_hash
  endpoint_service "keystone"
  endpoint_region node[:keystone][:api][:region]
  endpoint_adminURL KeystoneHelper.admin_auth_url(node, my_admin_host)
  endpoint_publicURL KeystoneHelper.public_auth_url(node, my_public_host)
  endpoint_internalURL KeystoneHelper.internal_auth_url(node, my_admin_host)
  action :update_endpoint
  # Do not try to update keystone endpoint during upgrade, when keystone is not running yet
  # ("done_os_upgrade" is present when first chef-client run is executed at the end of upgrade)
  not_if { node["crowbar_upgrade_step"] == "done_os_upgrade" }
  only_if do
    node[:keystone][:bootstrap] &&
      (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) &&
      node[:keystone].key?(:endpoint) &&
      (node[:keystone][:endpoint][:protocol] != node[:keystone][:api][:protocol] ||
      node[:keystone][:endpoint][:insecure] != node[:keystone][:ssl][:insecure] ||
      node[:keystone][:endpoint][:port] != node[:keystone][:api][:admin_port])
  end
end

template node[:keystone][:config_file] do
    source "keystone.conf.erb"
    owner "root"
    group node[:keystone][:group]
    mode 0640
    variables(
      sql_connection: sql_connection,
      sql_idle_timeout: node[:keystone][:sql][:idle_timeout],
      debug: node[:keystone][:debug],
      verbose: node[:keystone][:verbose],
      bind_admin_host: bind_admin_host,
      bind_service_host: bind_service_host,
      bind_admin_port: bind_admin_port,
      bind_service_port: bind_service_port,
      admin_endpoint: KeystoneHelper.service_URL(
        node[:keystone][:api][:protocol],
        my_admin_host, node[:keystone][:api][:admin_port]
      ),
      memcached_servers: memcached_servers,
      signing_token_format: node[:keystone][:signing][:token_format],
      signing_certfile: node[:keystone][:signing][:certfile],
      signing_keyfile: node[:keystone][:signing][:keyfile],
      signing_ca_certs: node[:keystone][:signing][:ca_certs],
      token_expiration: node[:keystone][:token_expiration],
      max_active_keys: max_active_keys,
      protocol: node[:keystone][:api][:protocol],
      frontend: node[:keystone][:frontend],
      rabbit_settings: fetch_rabbitmq_settings
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

  # Make sure the certificates code is run on the founder first
  crowbar_pacemaker_sync_mark "wait-keystone_certificates" do
    fatal true
  end
end

ruby_block "synchronize signing keys for founder and remember them for non-HA case" do
  only_if { (!ha_enabled || (ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node))) }
  block do
    ca = File.open("/etc/keystone/ssl/certs/ca.pem", "rb", &:read)
    signing_cert = File.open("/etc/keystone/ssl/certs/signing_cert.pem", "rb", &:read)
    signing_key = File.open("/etc/keystone/ssl/private/signing_key.pem", "rb", &:read)

    node[:keystone][:certificates] ||= {}
    node[:keystone][:certificates][:content] ||= {}

    dirty = false

    if node[:keystone][:certificates][:content][:ca] != ca
      node.set[:keystone][:certificates][:content][:ca] = ca
      dirty = true
    end
    if node[:keystone][:certificates][:content][:signing_cert] != signing_cert
      node.set[:keystone][:certificates][:content][:signing_cert] = signing_cert
      dirty = true
    end
    if node[:keystone][:certificates][:content][:signing_key] != signing_key
      node.set[:keystone][:certificates][:content][:signing_key] = signing_key
      dirty = true
    end

    node.save if dirty
  end
end

ruby_block "synchronize signing keys for non-founder" do
  only_if { ha_enabled && !CrowbarPacemakerHelper.is_cluster_founder?(node) }
  block do
    ca = File.open("/etc/keystone/ssl/certs/ca.pem", "rb", &:read)
    signing_cert = File.open("/etc/keystone/ssl/certs/signing_cert.pem", "rb", &:read)
    signing_key = File.open("/etc/keystone/ssl/private/signing_key.pem", "rb", &:read)

    founder = CrowbarPacemakerHelper.cluster_founder(node)

    cluster_ca = founder[:keystone][:certificates][:content][:ca]
    cluster_signing_cert = founder[:keystone][:certificates][:content][:signing_cert]
    cluster_signing_key = founder[:keystone][:certificates][:content][:signing_key]

    # The files exist; we will keep ownership / permissions with
    # the code below
    dirty = false
    if ca != cluster_ca
      File.open("/etc/keystone/ssl/certs/ca.pem", "w") { |f|
        f.write(cluster_ca)
      }
      dirty = true
    end
    if signing_cert != cluster_signing_cert
      File.open("/etc/keystone/ssl/certs/signing_cert.pem", "w") { |f|
        f.write(cluster_signing_cert)
      }
      dirty = true
    end
    if signing_key != cluster_signing_key
      File.open("/etc/keystone/ssl/private/signing_key.pem", "w") { |f|
        f.write(cluster_signing_key)
      }
      dirty = true
    end

    if dirty
      if node[:keystone][:frontend] == "apache"
        resources(service: "apache2").run_action(:restart)
      elsif node[:keystone][:frontend] == "uwsgi"
        resources(service: "keystone-uwsgi").run_action(:restart)
      end
    end
  end # block
end

crowbar_pacemaker_sync_mark "create-keystone_certificates" if ha_enabled

if node[:keystone][:api][:protocol] == "https"
  ssl_setup "setting up ssl for keystone" do
    generate_certs node[:keystone][:ssl][:generate_certs]
    certfile node[:keystone][:ssl][:certfile]
    keyfile node[:keystone][:ssl][:keyfile]
    group node[:keystone][:group]
    fqdn node[:fqdn]
    ca_certs node[:keystone][:ssl][:ca_certs]
  end
end

if ha_enabled
  include_recipe "keystone::ha"
end

# Configure Keystone token fernet backend provider
if node[:keystone][:signing][:token_format] == "fernet"
  # To be sure that rsync package is installed
  package "rsync"
  crowbar_pacemaker_sync_mark "sync-keystone_install_rsync" if ha_enabled
  rsync_command = ""
  if ha_enabled
    cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node)
    cluster_nodes.map do |n|
      next if node.name == n.name
      node_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
      rsync_command += \
        "rsync -a --timeout=300 --delete-after /etc/keystone/fernet-keys " \
        "#{node_address}:/etc/keystone/; "
    end
    raise "No other cluster members found" if rsync_command.empty?
  end

  # Rotate primary key, which is used for new tokens
  template "/var/lib/keystone/keystone-fernet-rotate" do
    source "keystone-fernet-rotate.erb"
    owner "root"
    group node[:keystone][:group]
    mode "0750"
    variables(
      rsync_command: rsync_command
    )
  end

  unless ha_enabled
    link "/etc/cron.hourly/openstack-keystone-fernet" do
      to "/var/lib/keystone/keystone-fernet-rotate"
    end
  end

  crowbar_pacemaker_sync_mark "wait-keystone_fernet_rotate" if ha_enabled

  unless File.exist?("/etc/keystone/fernet-keys/0")
    # Setup a key repository for fernet tokens
    execute "keystone-manage fernet_setup" do
      command "keystone-manage fernet_setup \
        --keystone-user #{node[:keystone][:user]} \
        --keystone-group #{node[:keystone][:group]}"
      action :run
      only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end

    # We would like to propagate fernet keys to all nodes in the cluster
    execute "propagate fernet keys to all nodes in the cluster" do
      command rsync_command
      action :run
      only_if { ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end

  service_transaction_objects = []

  keystone_fernet_primitive = "keystone-fernet-rotate"
  pacemaker_primitive keystone_fernet_primitive do
    agent node[:keystone][:ha][:fernet][:agent]
    params({
      "target" => "/var/lib/keystone/keystone-fernet-rotate",
      "link" => "/etc/cron.hourly/openstack-keystone-fernet",
      "backup_suffix" => ".orig"
    })
    op node[:keystone][:ha][:fernet][:op]
    action :update
    only_if { ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  service_transaction_objects << "pacemaker_primitive[#{keystone_fernet_primitive}]"

  fernet_rotate_loc = openstack_pacemaker_controller_only_location_for keystone_fernet_primitive
  service_transaction_objects << "pacemaker_location[#{fernet_rotate_loc}]"

  pacemaker_transaction "keystone-fernet-rotate cron" do
    cib_objects service_transaction_objects
    # note that this will also automatically start the resources
    action :commit_new
    only_if { ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  crowbar_pacemaker_sync_mark "create-keystone_fernet_rotate" if ha_enabled
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required services correctly configured and running before we create
# the keystone resources
crowbar_pacemaker_sync_mark "sync-keystone_before_register" if ha_enabled

crowbar_pacemaker_sync_mark "wait-keystone_register" if ha_enabled

keystone_insecure = node["keystone"]["api"]["protocol"] == "https" && node[:keystone][:ssl][:insecure]

# Creates admin user, admin role and admin project
execute "keystone-manage bootstrap" do
  command "keystone-manage bootstrap \
  --bootstrap-password #{node[:keystone][:admin][:password]} \
  --bootstrap-username #{node[:keystone][:admin][:username]} \
  --bootstrap-project-name #{node[:keystone][:admin][:tenant]} \
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

register_auth_hash = { user: node[:keystone][:admin][:username],
                       password: node[:keystone][:admin][:password],
                       tenant: node[:keystone][:admin][:tenant] }

updated_password = node[:keystone][:admin][:updated_password]

unless updated_password.nil? ||
    updated_password.empty? ||
    updated_password == node[:keystone][:admin][:password]

  if !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)
    keystone_register "update admin password" do
      protocol node[:keystone][:api][:protocol]
      insecure keystone_insecure
      host my_admin_host
      port node[:keystone][:api][:admin_port]
      auth register_auth_hash
      user_name node[:keystone][:admin][:username]
      user_password updated_password
      tenant_name node[:keystone][:admin][:tenant]
      action :nothing
    end.run_action(:add_user)
  end

  ruby_block "update admin password on node attributes" do
    block do
      node.set[:keystone][:admin][:password] = updated_password
      node.save
      register_auth_hash[:password] = updated_password
    end
    action :nothing
  end.run_action(:create)
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

[:service, :default].each do |tenant_type|
  tenant = node[:keystone][tenant_type][:tenant]

  keystone_register "add default #{tenant} tenant" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    port node[:keystone][:api][:admin_port]
    auth register_auth_hash
    tenant_name tenant
    action :add_tenant
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
    tenant_name node[:keystone][:default][:tenant]
    action :add_user
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

# Create Member role used by horizon (see OPENSTACK_KEYSTONE_DEFAULT_ROLE option)
keystone_register "add default Member role" do
  protocol node[:keystone][:api][:protocol]
  insecure keystone_insecure
  host my_admin_host
  port node[:keystone][:api][:admin_port]
  auth register_auth_hash
  role_name "Member"
  action :add_role
  only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Create Access info
user_roles = [
  [node[:keystone][:admin][:username], "admin", node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], "admin", node[:keystone][:default][:tenant]]
]
if node[:keystone][:default][:create_user]
  user_roles << [node[:keystone][:default][:username], "Member", node[:keystone][:default][:tenant]]
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
    tenant_name args[2]
    action :add_access
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

# Create EC2 creds for our users
ec2_creds = [
  [node[:keystone][:admin][:username], node[:keystone][:admin][:tenant]],
  [node[:keystone][:admin][:username], node[:keystone][:default][:tenant]]
]
if node[:keystone][:default][:create_user]
  ec2_creds << [node[:keystone][:default][:username], node[:keystone][:default][:tenant]]
end
ec2_creds.each do |args|
  keystone_register "add default ec2 creds for #{args[1]}:#{args[0]}" do
    protocol node[:keystone][:api][:protocol]
    insecure keystone_insecure
    host my_admin_host
    auth register_auth_hash
    port node[:keystone][:api][:admin_port]
    user_name args[0]
    tenant_name args[1]
    action :add_ec2
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

crowbar_pacemaker_sync_mark "create-keystone_register" if ha_enabled

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

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
