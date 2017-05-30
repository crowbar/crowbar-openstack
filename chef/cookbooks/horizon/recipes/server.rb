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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if %w(suse).include? node[:platform_family]
  dashboard_path = "/srv/www/openstack-dashboard"
else
  dashboard_path = "/usr/share/openstack-dashboard"
end

if node[:horizon][:apache][:ssl]
  include_recipe "apache2::mod_ssl"
end

# Fake service to take control of the WSGI process from apache that
# runs Horizon.  We replace the `reload` action, sending manually the
# signal SIGUSR1 to all the process that are part of `wsgi:horizon`
service "horizon" do
  service_name "apache2"
  if node[:platform_family] == "suse"
    reload_command 'sleep 1 && pkill --signal SIGUSR1 -f "^\(wsgi:horizon\)" && sleep 1'
  end
  supports reload: true, restart: true, status: true
  ignore_failure true
end

case node[:platform_family]
when "debian"
  # Explicitly added client dependencies for now.
  packages = ["python-lesscpy", "python-ply", "openstack-dashboard", "python-novaclient", "python-glance", "python-swift", "python-keystone", "openstackx", "python-django", "python-django-horizon", "python-django-nose"]
  packages.each do |pkg|
    package pkg do
      action :install
    end
  end

  rm_pkgs = ["openstack-dashboard-ubuntu-theme"]
  rm_pkgs.each do |pkg|
    package pkg do
      action :purge
    end
  end
when "rhel"
  package "openstack-dashboard"
  package "python-lesscpy"
else
  # On SUSE, the package has the correct list of dependencies
  package "openstack-dashboard"

  # Install the configured branding
  unless node[:horizon][:site_theme].empty?
    package "openstack-dashboard-theme-#{node[:horizon][:site_theme]}" do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

# install horizon neutron lbaas plugin if needed
neutron_lbaas_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-neutron-lbaas-ui"
  when "rhel"
    "openstack-neutron-lbaas-ui"
  end

unless neutron_lbaas_ui_pkgname.nil?
  neutron_servers = search(:node, "roles:neutron-server") || []
  unless neutron_servers.empty?
    package neutron_lbaas_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

# install horizon manila plugin if needed
manila_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-manila-ui"
  when "rhel"
    "openstack-manila-ui"
  end

unless manila_ui_pkgname.nil?
  manila_servers = search(:node, "roles:manila-server") || []
  unless manila_servers.empty?
    package manila_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

# install horizon magnum plugin if needed
magnum_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-magnum-ui"
  when "rhel"
    "openstack-magnum-ui"
  end

unless magnum_ui_pkgname.nil?
  magnum_servers = search(:node, "roles:magnum-server") || []
  unless magnum_servers.empty?
    package magnum_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

# install horizon trove plugin if needed
trove_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-trove-ui"
  when "rhel"
    "openstack-trove-ui"
  end

unless trove_ui_pkgname.nil?
  trove_servers = search(:node, "roles:trove-server") || []
  unless trove_servers.empty?
    package trove_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

# install horizon sahara plugin if needed
sahara_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-sahara-ui"
  when "rhel"
    "openstack-sahara-ui"
  end

unless sahara_ui_pkgname.nil?
  sahara_servers = search(:node, "roles:sahara-server") || []
  unless sahara_servers.empty?
    package sahara_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

# install horizon ironic plugin if needed
ironic_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-ironic-ui"
  when "rhel"
    "openstack-ironic-ui"
  end

unless ironic_ui_pkgname.nil?
  ironic_servers = search(:node, "roles:ironic-server") || []
  unless ironic_servers.empty?
    package ironic_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
  end
end

monasca_ui_pkgname =
  case node[:platform_family]
  when "suse"
    "openstack-horizon-plugin-monasca-ui"
  when "rhel"
    "openstack-monasca-ui"
  end

unless monasca_ui_pkgname.nil?
  monasca_servers = node_search_with_cache("roles:monasca-server")
  unless monasca_servers.empty?
    include_recipe "#{@cookbook_name}::monasca_ui"
    package monasca_ui_pkgname do
      action :install
      notifies :reload, "service[horizon]"
    end
    grafana_available = true
  end
end

if node[:platform_family] == "suse"
  # Get rid of unwanted vhost config files:
  ["#{node[:apache][:dir]}/vhosts.d/default-redirect.conf",
   "#{node[:apache][:dir]}/vhosts.d/nova-dashboard.conf"].each do |f|
    file f do
      action :delete
    end
  end

  template "/etc/logrotate.d/openstack-dashboard" do
    source "openstack-dashboard.logrotate.erb"
    mode 0644
    owner "root"
    group "root"
  end

  apache_module "deflate" do
    conf false
    enable true
  end
else
  directory "#{dashboard_path}/.blackhole" do
    owner node[:apache][:user]
    group node[:apache][:group]
    mode "0755"
    action :create
  end

  directory "/var/www" do
    owner node[:apache][:user]
    group node[:apache][:group]
    mode "0755"
    action :create
  end

  apache_site "000-default" do
    enable false
  end

  file "/etc/apache2/conf.d/openstack-dashboard.conf" do
    action :delete
  end

  # remove old apache config file
  file "#{node[:apache][:dir]}/sites-available/nova-dashboard.conf" do
    action :delete
  end
end

ha_enabled = node[:horizon][:ha][:enabled]

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

case db_settings[:backend_name]
when "mysql"
    django_db_backend = "'django.db.backends.mysql'"
when "postgresql"
    django_db_backend = "'django.db.backends.postgresql_psycopg2'"
end

crowbar_pacemaker_sync_mark "wait-horizon_database" if ha_enabled

# Create the Dashboard Database
database "create #{node[:horizon][:db][:database]} database" do
    connection db_settings[:connection]
    database_name node[:horizon][:db][:database]
    provider db_settings[:provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "create dashboard database user" do
    connection db_settings[:connection]
    database_name node[:horizon][:db][:database]
    username node[:horizon][:db][:user]
    password node[:horizon][:db][:password]
    host "%"
    provider db_settings[:user_provider]
    action :create
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

database_user "grant database access for dashboard database user" do
    connection db_settings[:connection]
    database_name node[:horizon][:db][:database]
    username node[:horizon][:db][:user]
    password node[:horizon][:db][:password]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    action :grant
    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-horizon_database" if ha_enabled

db_settings = {
  "ENGINE" => django_db_backend,
  "NAME" => "'#{node[:horizon][:db][:database]}'",
  "USER" => "'#{node[:horizon][:db][:user]}'",
  "PASSWORD" => "'#{node[:horizon][:db][:password]}'",
  "HOST" => "'#{db_settings[:address]}'",
  "default-character-set" => "'utf8'"
}

glances = search(:node, "roles:glance-server") || []
if glances.length > 0
  glance = glances[0]
  glance_insecure = glance[:glance][:api][:protocol] == "https" && glance[:glance][:ssl][:insecure]
else
  glance_insecure = false
end

cinders = search(:node, "roles:cinder-controller") || []
if cinders.length > 0
  cinder = cinders[0]
  cinder_insecure = cinder[:cinder][:api][:protocol] == "https" && cinder[:cinder][:ssl][:insecure]
else
  cinder_insecure = false
end

neutrons = search(:node, "roles:neutron-server") || []
if neutrons.length > 0
  neutron = neutrons[0]
  neutron_insecure = neutron[:neutron][:api][:protocol] == "https" && neutron[:neutron][:ssl][:insecure]
  if neutron[:neutron][:networking_plugin] == "ml2"
    neutron_ml2_type_drivers = neutron[:neutron][:ml2_type_drivers]
  else
    neutron_ml2_type_drivers = "'*'"
  end
  neutron_use_lbaas = neutron[:neutron][:use_lbaas]
  neutron_use_vpnaas = neutron[:neutron][:use_vpnaas]
else
  neutron_insecure = false
  neutron_ml2_type_drivers = "'*'"
  neutron_use_lbaas = false
  neutron_use_vpnaas = false
end

novas = search(:node, "roles:nova-controller") || []
if !novas.empty?
  nova = novas[0]
  nova_insecure = nova[:nova][:ssl][:enabled] && nova[:nova][:ssl][:insecure]
else
  nova_insecure = false
end

heats = search(:node, "roles:heat-server") || []
if !heats.empty?
  heat = heats[0]
  heat_insecure = heat[:heat][:api][:protocol] == "https" && heat[:heat][:ssl][:insecure]
else
  heat_insecure = false
end

manilas = search(:node, "roles:manila-server")
if !manilas.empty?
  manila = manilas[0]
  manila_insecure = manila[:manila][:api][:protocol] == "https" && manila[:manila][:ssl][:insecure]
else
  manila_insecure = false
end

ceilometers = search(:node, "roles:ceilometer-server") || []
if !ceilometers.empty?
  ceilometer = ceilometers[0][:ceilometer]
  ceilometer_insecure = ceilometer[:api][:protocol] == "https" && ceilometer[:ssl][:insecure]
else
  ceilometer_insecure = false
end

# We're going to use memcached as a cache backend for Django

# make sure our memcache only listens on the admin IP address
node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
node.set[:memcached][:listen] = node_admin_ip
node.save

if ha_enabled
  memcached_nodes = CrowbarPacemakerHelper.cluster_nodes(node, "horizon-server")
  memcached_locations = memcached_nodes.map do |n|
    node_admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(n, "admin").address
    "#{node_admin_ip}:#{n[:memcached][:port] rescue node[:memcached][:port]}"
  end
else
  memcached_locations = ["#{node_admin_ip}:#{node[:memcached][:port]}"]
end
memcached_locations.sort!

memcached_instance "openstack-dashboard"
case node[:platform_family]
when "suse"
  package "python-python-memcached"
when "debian"
  package "python-memcache"
when "rhel"
  package "python-memcached"
end

crowbar_pacemaker_sync_mark "wait-horizon_config" if ha_enabled

local_settings = "#{dashboard_path}/openstack_dashboard/local/" \
                 "local_settings.d/_100_local_settings.py"

# We need to protect syncdb with crowbar_pacemaker_sync_mark. Since it's run in
# an immmediate notification of the creation of the config file, we put the two
# between the crowbar_pacemaker_sync_mark calls.
execute "python manage.py migrate" do
  cwd dashboard_path
  environment ({"PYTHONPATH" => dashboard_path})
  command "python manage.py migrate --fake-initial --noinput"
  user node[:apache][:user]
  group node[:apache][:group]
  action :nothing
  subscribes :run, "template[#{local_settings}]", :immediately
  notifies :restart, resources(service: "apache2"), :immediately
end

# Force-disable multidomain support when the default keystoneapi version is too
# old
multi_domain_support = keystone_settings["api_version"].to_f < 3.0 ? false : node["horizon"]["multi_domain_support"]

# Verify that we have the certificate available before configuring things to use it
if node[:horizon][:apache][:ssl] && !node[:horizon][:apache][:generate_certs]
  unless ::File.size? node[:horizon][:apache][:ssl_crt_file]
    message = "The file \"#{node[:horizon][:apache][:ssl_crt_file]}\" does not exist or is empty."
    Chef::Log.fatal(message)
    raise message
  end
  # we do not check for existence of keyfile, as the private key is allowed
  # to be in the certfile
end

# Need to template the "EXTERNAL_MONITORING" array
template local_settings do
  source "local_settings.py.erb"
  owner node[:apache][:user]
  group "root"
  mode "0640"
  variables(
    debug: node[:horizon][:debug],
    keystone_settings: keystone_settings,
    insecure: keystone_settings["insecure"] \
    || glance_insecure \
    || cinder_insecure \
    || neutron_insecure \
    || nova_insecure \
    || heat_insecure \
    || manila_insecure \
    || ceilometer_insecure,
    db_settings: db_settings,
    enable_lb: neutron_use_lbaas,
    enable_vpn: neutron_use_vpnaas,
    timezone: (node[:provisioner][:timezone] rescue "UTC") || "UTC",
    use_ssl: node[:horizon][:apache][:ssl],
    password_validator_regex: node[:horizon][:password_validator][:regex],
    password_validator_help_text: node[:horizon][:password_validator][:help_text],
    site_branding: node[:horizon][:site_branding],
    site_branding_link: node[:horizon][:site_branding_link],
    neutron_ml2_type_drivers: neutron_ml2_type_drivers,
    help_url: node[:horizon][:help_url],
    session_timeout: node[:horizon][:session_timeout],
    memcached_locations: memcached_locations,
    can_set_mount_point: node["horizon"]["can_set_mount_point"],
    can_set_password: node["horizon"]["can_set_password"],
    multi_domain_support: multi_domain_support,
    policy_file_path: node["horizon"]["policy_file_path"],
    policy_file: node["horizon"]["policy_file"],
    token_hash_enabled: node["horizon"]["token_hash_enabled"]
  )
  action :create
end

crowbar_pacemaker_sync_mark "create-horizon_config" if ha_enabled

if ha_enabled
  log "HA support for horizon is enabled"
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:horizon][:ha][:ports][:plain]
  bind_port_ssl = node[:horizon][:ha][:ports][:ssl]
else
  log "HA support for horizon is disabled"
  bind_host = "*"
  bind_port = 80
  bind_port_ssl = 443
end

node.normal[:apache][:listen_ports_crowbar] ||= {}

if node[:horizon][:apache][:ssl]
  node.normal[:apache][:listen_ports_crowbar][:horizon] = { plain: [bind_port], ssl: [bind_port_ssl] }
else
  node.normal[:apache][:listen_ports_crowbar][:horizon] = { plain: [bind_port] }
end

# we can only include the recipe after having defined the listen_ports_crowbar attribute
include_recipe "horizon::ha" if ha_enabled

# Override what the apache2 cookbook does since it enforces the ports
resource = resources(template: "#{node[:apache][:dir]}/ports.conf")
resource.variables({apache_listen_ports: node.normal[:apache][:listen_ports_crowbar].values.map{ |p| p.values }.flatten.uniq.sort})

if node[:horizon][:apache][:ssl] && node[:horizon][:apache][:generate_certs]
  package "apache2-utils"

  bash "Generate Apache certificate" do
    code <<-EOH
      (umask 377 ; /usr/bin/gensslcert -C openstack-dashboard )
EOH
    not_if { File.size?(node[:horizon][:apache][:ssl_crt_file]) }
  end
end

template "#{node[:apache][:dir]}/sites-available/openstack-dashboard.conf" do
  if node[:platform_family] == "suse"
    path "#{node[:apache][:dir]}/vhosts.d/openstack-dashboard.conf"
  end
  source "openstack-dashboard.conf.erb"
  mode 0644
  variables(
    behind_proxy: ha_enabled,
    bind_host: bind_host,
    bind_port: bind_port,
    bind_port_ssl: bind_port_ssl,
    horizon_dir: dashboard_path,
    user: node[:apache][:user],
    group: node[:apache][:group],
    use_ssl: node[:horizon][:apache][:ssl],
    ssl_crt_file: node[:horizon][:apache][:ssl_crt_file],
    ssl_key_file: node[:horizon][:apache][:ssl_key_file],
    ssl_crt_chain_file: node[:horizon][:apache][:ssl_crt_chain_file],
    grafana_available: defined?(grafana_available) ? grafana_available : false
  )
  if ::File.symlink?("#{node[:apache][:dir]}/sites-enabled/openstack-dashboard.conf") || node[:platform_family] == "suse"
    notifies :reload, resources(service: "apache2")
  end
end

apache_site "openstack-dashboard.conf" do
  enable true
end
