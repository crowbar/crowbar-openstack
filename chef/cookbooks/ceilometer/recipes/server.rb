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

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

if node[:ceilometer][:use_mongodb]
  case node["platform"]
    when "centos", "redhat"
      mongo_conf = "/etc/mongod.conf"
      mongo_service = "mongod"
      package "mongo-10gen"
      package "mongo-10gen-server"
    else
      mongo_conf = "/etc/mongodb.conf"
      mongo_service = "mongodb"
      package "mongodb" do
        action :install
      end
  end

  service "#{mongo_service}" do
    supports :status => true, :restart => true
    action :enable
  end

  template "#{mongo_conf}" do
    mode 0644
    source "mongodb.conf.erb"
    variables(:listen_addr => Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address)
    notifies :restart, resources(:service => "#{mongo_service}"), :immediately
  end
else
  node.set_unless[:ceilometer][:db][:password] = secure_password

  env_filter = " AND database_config_environment:database-config-#{node[:ceilometer][:database_instance]}"
  sqls = search(:node, "roles:database-server#{env_filter}") || []
  if sqls.length > 0
      sql = sqls[0]
      sql = node if sql.name == node.name
  else
      sql = node
  end
  include_recipe "database::client"
  backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
  include_recipe "#{backend_name}::client"
  include_recipe "#{backend_name}::python-client"

  db_provider = Chef::Recipe::Database::Util.get_database_provider(sql)
  db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql)
  privs = Chef::Recipe::Database::Util.get_default_priviledges(sql)

  sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
  Chef::Log.info("Database server found at #{sql_address}")

  db_conn = { :host => sql_address,
              :username => "db_maker",
              :password => sql[:database][:db_maker_password] }

  # Create the Ceilometer Database
  database "create #{node[:ceilometer][:db][:database]} database" do
      connection db_conn
      database_name node[:ceilometer][:db][:database]
      provider db_provider
      action :create
  end

  database_user "create ceilometer database user" do
      host '%'
      connection db_conn
      username node[:ceilometer][:db][:user]
      password node[:ceilometer][:db][:password]
      provider db_user_provider
      action :create
  end

  database_user "grant database access for ceilometer database user" do
      connection db_conn
      username node[:ceilometer][:db][:user]
      password node[:ceilometer][:db][:password]
      database_name node[:ceilometer][:db][:database]
      host '%'
      privileges privs
      provider db_user_provider
      action :grant
  end
end

unless node[:ceilometer][:use_gitrepo]
  case node["platform"]
    when "suse"
      package "openstack-ceilometer-collector"
      package "openstack-ceilometer-api"
    when "centos", "redhat"
      package "openstack-ceilometer-common"
      package "openstack-ceilometer-collector"
      package "openstack-ceilometer-api"
      package "python-ceilometerclient"
    else
      package "python-ceilometerclient"
      package "ceilometer-common"
      package "ceilometer-collector"
      package "ceilometer-api"
  end
else
  ceilometer_path = "/opt/ceilometer"

  venv_path = node[:ceilometer][:use_virtualenv] ? "#{ceilometer_path}/.venv" : nil
  venv_prefix = node[:ceilometer][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil
  puts "venv_path=#{venv_path}"
  puts "use_virtualenv=#{node[:ceilometer][:use_virtualenv]}"
  pfs_and_install_deps "ceilometer" do
    cookbook "ceilometer"
    cnode node
    virtualenv venv_path
    path ceilometer_path
    wrap_bins [ "ceilometer" ]
  end

  link_service "ceilometer-collector" do
    virtualenv venv_path
  end
  link_service "ceilometer-api" do
    virtualenv venv_path
  end

  create_user_and_dirs("ceilometer")
  execute "cp_policy.json" do
    command "cp #{ceilometer_path}/etc/ceilometer/policy.json /etc/ceilometer"
    creates "/etc/ceilometer/policy.json"
  end
  execute "cp_pipeline.yaml" do
    command "cp #{ceilometer_path}/etc/ceilometer/pipeline.yaml /etc/ceilometer"
    creates "/etc/ceilometer/pipeline.yaml"
  end
end

node.set_unless[:ceilometer][:metering_secret] = secure_password

include_recipe "#{@cookbook_name}::common"

directory "/var/cache/ceilometer" do
  owner node[:ceilometer][:user]
  group "root"
  mode 00755
  action :create
end unless node.platform == "suse"

env_filter = " AND keystone_config_environment:keystone-config-#{node[:ceilometer][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_host = keystone[:fqdn]
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_token = keystone["keystone"]["service"]["token"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["ceilometer"]["keystone_service_user"]
keystone_service_password = node["ceilometer"]["keystone_service_password"]
Chef::Log.info("Keystone server found at #{keystone_host}")

my_admin_host = node[:fqdn]
# For the public endpoint, we prefer the public name. If not set, then we
# use the IP address except for SSL, where we always prefer a hostname
# (for certificate validation).
my_public_host = node[:crowbar][:public_name]
if my_public_host.nil? or my_public_host.empty?
  unless node[:ceilometer][:api][:protocol] == "https"
    my_public_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
  else
    my_public_host = 'public.'+node[:fqdn]
  end
end

execute "calling ceilometer-dbsync" do
  command "#{venv_prefix}ceilometer-dbsync"
  action :run
end

service "ceilometer-collector" do
  service_name "openstack-ceilometer-collector" if %w(redhat centos suse).include?(node.platform)
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :enable, :start ]
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
end

service "ceilometer-api" do
  service_name "openstack-ceilometer-api" if %w(redhat centos suse).include?(node.platform)
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :enable, :start ]
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
end

keystone_register "register ceilometer user" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give ceilometer user access" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

# Create ceilometer service
keystone_register "register ceilometer service" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  service_name "ceilometer"
  service_type "metering"
  service_description "Openstack Collector Service"
  action :add_service
end

keystone_register "register ceilometer endpoint" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  endpoint_service "ceilometer"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{node[:ceilometer][:api][:protocol]}://#{my_public_host}:#{node[:ceilometer][:api][:port]}/"
  endpoint_adminURL "#{node[:ceilometer][:api][:protocol]}://#{my_admin_host}:#{node[:ceilometer][:api][:port]}/"
  endpoint_internalURL "#{node[:ceilometer][:api][:protocol]}://#{my_admin_host}:#{node[:ceilometer][:api][:port]}/"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

node.save
