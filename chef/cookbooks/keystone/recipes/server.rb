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

# Ideally this would be called admin_host, but that's already being
# misleadingly used to store a value which actually represents the
# service bind address.
my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:keystone][:api][:protocol] == "https", ha_enabled)

# These are used in keystone.conf
node.set[:keystone][:api][:public_URL] = \
  KeystoneHelper.service_URL(node[:keystone][:api][:protocol],
                             my_public_host,
                             node[:keystone][:api][:service_port])
# This is also used for admin requests of keystoneclient
node.set[:keystone][:api][:admin_URL] = \
  KeystoneHelper.service_URL(node[:keystone][:api][:protocol],
                             my_admin_host,
                             node[:keystone][:api][:admin_port])

# These URLs will be registered as endpoints in keystone's database
node.set[:keystone][:api][:versioned_public_URL] = \
  KeystoneHelper.versioned_service_URL(node[:keystone][:api][:protocol],
                                       my_public_host,
                                       node[:keystone][:api][:service_port],
                                       node[:keystone][:api][:version])
node.set[:keystone][:api][:versioned_admin_URL] = \
  KeystoneHelper.versioned_service_URL(node[:keystone][:api][:protocol],
                                       my_admin_host,
                                       node[:keystone][:api][:admin_port],
                                       node[:keystone][:api][:version])
node.set[:keystone][:api][:versioned_internal_URL] = \
  KeystoneHelper.versioned_service_URL(node[:keystone][:api][:protocol],
                                       my_admin_host,
                                       node[:keystone][:api][:service_port],
                                       node[:keystone][:api][:version])

# Other barclamps need to know the hostname to reach keystone
node.set[:keystone][:api][:public_URL_host] = my_public_host
node.set[:keystone][:api][:internal_URL_host] = my_admin_host

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

  include_recipe "apache2"
  if %w(rhel).include?(node[:platform_family])
    package "mod_wsgi"
  else
    include_recipe "apache2::mod_wsgi"
  end
  include_recipe "apache2::mod_rewrite"
  apache_module "version"

  apache_site "000-default" do
    enable false
  end

  apache_log_dir = if node[:platform_family] == "suse"
    "/var/log/apache2"
  else
    "${APACHE_LOG_DIR}"
  end

  apache_module "ssl" if node[:keystone][:api][:protocol] == "https"

  template "#{node[:apache][:dir]}/sites-available/keystone.conf" do
    path "#{node[:apache][:dir]}/vhosts.d/keystone.conf" if node[:platform_family] == "suse"
    source "apache_keystone.conf.erb"
    variables(
      apache_log_dir: apache_log_dir,
      bind_admin_port: bind_admin_port, # Auth port
      bind_admin_host: bind_admin_host,
      bind_service_port: bind_service_port, # public port
      bind_service_host: bind_service_host,
      ssl_enable: node[:keystone][:api][:protocol] == "https",
      ssl_certfile: node[:keystone][:ssl][:certfile],
      ssl_keyfile: node[:keystone][:ssl][:keyfile],
      ssl_ca_certs: node[:keystone][:ssl][:ca_certs],
      processes: 3,
      threads: 10
    )
    notifies :restart, resources(service: "apache2"), :immediately
  end

  apache_site "keystone.conf" do
    enable true
  end
end

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

crowbar_pacemaker_sync_mark "wait-keystone_database"

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
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-keystone_database"

sql_connection = "#{db_settings[:url_scheme]}://#{node[:keystone][:db][:user]}:#{node[:keystone][:db][:password]}@#{db_settings[:address]}/#{node[:keystone][:db][:database]}"

template "/etc/keystone/keystone.conf" do
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
      admin_endpoint: node[:keystone][:api][:admin_URL],
      use_syslog: node[:keystone][:use_syslog],
      signing_token_format: node[:keystone][:signing][:token_format],
      signing_certfile: node[:keystone][:signing][:certfile],
      signing_keyfile: node[:keystone][:signing][:keyfile],
      signing_ca_certs: node[:keystone][:signing][:ca_certs],
      token_expiration: node[:keystone][:token_expiration],
      protocol: node[:keystone][:api][:protocol],
      frontend: node[:keystone][:frontend],
      ssl_enable: (node[:keystone][:frontend] == "native" && node[:keystone][:api][:protocol] == "https"),
      ssl_certfile: node[:keystone][:ssl][:certfile],
      ssl_keyfile: node[:keystone][:ssl][:keyfile],
      ssl_ca_certs: node[:keystone][:ssl][:ca_certs],
      rabbit_settings: fetch_rabbitmq_settings
    )
    if node[:keystone][:frontend] == "apache"
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

crowbar_pacemaker_sync_mark "wait-keystone_db_sync"

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

crowbar_pacemaker_sync_mark "create-keystone_db_sync"

# Make sure the PKI bits are done on the founder first
crowbar_pacemaker_sync_mark "wait-keystone_pki" do
  fatal true
end

unless node[:platform_family] == "suse"
  if node[:keystone][:signing][:token_format] == "PKI"
    execute "keystone-manage ssl_setup" do
      user node[:keystone][:user]
      group node[:keystone][:group]
      command "keystone-manage ssl_setup --keystone-user #{node[:keystone][:user]} --keystone-group  #{node[:keystone][:group]}"
      action :run
    end
    execute "keystone-manage pki_setup" do
      user node[:keystone][:user]
      group node[:keystone][:group]
      command "keystone-manage pki_setup --keystone-user #{node[:keystone][:user]} --keystone-group  #{node[:keystone][:group]}"
      action :run
    end
  end
end

ruby_block "synchronize PKI keys for founder and remember them for non-HA case" do
  only_if { (!ha_enabled || (ha_enabled && CrowbarPacemakerHelper.is_cluster_founder?(node))) &&
            (node[:keystone][:signing][:token_format] == "PKI" || node[:platform_family] == "suse") }
  block do
    ca = File.open("/etc/keystone/ssl/certs/ca.pem", "rb") { |io| io.read } rescue ""
    signing_cert = File.open("/etc/keystone/ssl/certs/signing_cert.pem", "rb") { |io| io.read } rescue ""
    signing_key = File.open("/etc/keystone/ssl/private/signing_key.pem", "rb") { |io| io.read } rescue ""

    node[:keystone][:pki] ||= {}
    node[:keystone][:pki][:content] ||= {}

    dirty = false

    if node[:keystone][:pki][:content][:ca] != ca
      node.set[:keystone][:pki][:content][:ca] = ca
      dirty = true
    end
    if node[:keystone][:pki][:content][:signing_cert] != signing_cert
      node.set[:keystone][:pki][:content][:signing_cert] = signing_cert
      dirty = true
    end
    if node[:keystone][:pki][:content][:signing_key] != signing_key
      node.set[:keystone][:pki][:content][:signing_key] = signing_key
      dirty = true
    end

    node.save if dirty
  end
end

ruby_block "synchronize PKI keys for non-founder" do
  only_if { ha_enabled && !CrowbarPacemakerHelper.is_cluster_founder?(node) && (node[:keystone][:signing][:token_format] == "PKI" || node[:platform_family] == "suse") }
  block do
    ca = File.open("/etc/keystone/ssl/certs/ca.pem", "rb") { |io| io.read } rescue ""
    signing_cert = File.open("/etc/keystone/ssl/certs/signing_cert.pem", "rb") { |io| io.read } rescue ""
    signing_key = File.open("/etc/keystone/ssl/private/signing_key.pem", "rb") { |io| io.read } rescue ""

    founder = CrowbarPacemakerHelper.cluster_founder(node)

    cluster_ca = founder[:keystone][:pki][:content][:ca]
    cluster_signing_cert = founder[:keystone][:pki][:content][:signing_cert]
    cluster_signing_key = founder[:keystone][:pki][:content][:signing_key]

    # The files exist; we will keep ownership / permissions with
    # the code below
    dirty = false
    if ca != cluster_ca
      File.open("/etc/keystone/ssl/certs/ca.pem", "w") { |f| f.write(cluster_ca) }
      dirty = true
    end
    if signing_cert != cluster_signing_cert
      File.open("/etc/keystone/ssl/certs/signing_cert.pem", "w") { |f| f.write(cluster_signing_cert) }
      dirty = true
    end
    if signing_key != cluster_signing_key
      File.open("/etc/keystone/ssl/private/signing_key.pem", "w") { |f| f.write(cluster_signing_key) }
      dirty = true
    end

    if dirty
      if node[:keystone][:frontend] == "native"
        resources(service: "keystone").run_action(:restart)
      elsif node[:keystone][:frontend] == "apache"
        resources(service: "apache2").run_action(:restart)
      elsif node[:keystone][:frontend] == "uwsgi"
        resources(service: "keystone-uwsgi").run_action(:restart)
      end
    end
  end # block
end

crowbar_pacemaker_sync_mark "create-keystone_pki"

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

if node[:keystone][:frontend] == "native"
  # We define the service after we define all our config files, so that it's
  # started only when all files are created.
  service "keystone" do
    service_name node[:keystone][:service_name]
    supports status: true, start: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/keystone/keystone.conf"), :immediately
    provider Chef::Provider::CrowbarPacemakerService if ha_enabled
  end
end

if ha_enabled
  include_recipe "keystone::ha"
end

crowbar_pacemaker_sync_mark "wait-keystone_register"

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
  --bootstrap-admin-url #{node[:keystone][:api][:versioned_admin_URL]} \
  --bootstrap-public-url #{node[:keystone][:api][:versioned_public_URL]} \
  --bootstrap-internal-url #{node[:keystone][:api][:versioned_internal_URL]}"
  action :run
  only_if do
    !node[:keystone][:bootstrap] &&
      (!ha_enabled || (CrowbarPacemakerHelper.is_cluster_founder?(node) &&
        !CrowbarPacemakerHelper.being_upgraded?(node))
      )
  end
end

register_auth_hash = { user: node[:keystone][:admin][:username],
                       password: node[:keystone][:admin][:password],
                       tenant: node[:keystone][:admin][:tenant] }

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

# Create tenants
openstack_command = "openstack \
--os-username \"#{node[:keystone][:admin][:username]}\" \
--os-password \"#{node[:keystone][:admin][:password]}\" \
--os-project-name \"#{node[:keystone][:admin][:tenant]}\" \
--os-auth-url \"#{node[:keystone][:api][:versioned_admin_URL]}\" \
--os-region \"#{node[:keystone][:api][:region]}\""
if node[:keystone][:api][:version] != "2.0"
  openstack_command <<  " --os-identity-api-version #{node[:keystone][:api][:version]} --os-project-domain-id default --os-user-domain-id default"
end

openstack_command << " --insecure" if keystone_insecure

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
  end

  ruby_block "saving id for default #{tenant} tenant" do
    block do
      tenant_id = `#{openstack_command} project show -f value -c id #{tenant}`.chomp
      if !tenant_id.empty? && node[:keystone][tenant_type][:tenant_id] != tenant_id
        node.set[:keystone][tenant_type][:tenant_id] = tenant_id
        node.save
      end
    end
  end
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
  end
end

crowbar_pacemaker_sync_mark "create-keystone_register"

node.set[:keystone][:monitor] = {} if node[:keystone][:monitor].nil?
node.set[:keystone][:monitor][:svcs] = ["keystone"] if node[:keystone][:monitor][:svcs] != ["keystone"]
node.save

template "/root/.openrc" do
  source "openrc.erb"
  owner "root"
  group "root"
  mode 0600
  variables(
    keystone_settings: KeystoneHelper.keystone_settings(node, @cookbook_name)
    )
end
