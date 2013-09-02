# Copyright 2013 SUSE, Inc.
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

node.set_unless[:heat][:db][:password] = secure_password

env_filter = " AND database_config_environment:database-config-#{node[:heat][:database_instance]}"
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

# Create the Heat Database
database "create #{node[:heat][:db][:database]} database" do
    connection db_conn
    database_name node[:heat][:db][:database]
    provider db_provider
    action :create
end

database_user "create heat database user" do
    host '%'
    connection db_conn
    username node[:heat][:db][:user]
    password node[:heat][:db][:password]
    provider db_user_provider
    action :create
end

database_user "grant database access for heat database user" do
    connection db_conn
    username node[:heat][:db][:user]
    password node[:heat][:db][:password]
    database_name node[:heat][:db][:database]
    host '%'
    privileges privs
    provider db_user_provider
    action :grant
end

unless node[:heat][:use_gitrepo]
  unless node.platform == "suse"
    package "heat-api"
    package "python-heatclient"
  else
    package "openstack-heat-api"
    package "openstack-heat-api-cfn"
    package "openstack-heat-api-cloudwatch"
    package "openstack-heat-engine"
    package "python-heatclient"
  end
  venv_prefix = nil
else
  heat_path = "/opt/heat"
  pfs_and_install_deps("heat")
  link_service "heat-api"
  create_user_and_dirs("heat")
  execute "cp_policy.json" do
    command "cp #{heat_path}/etc/policy.json /etc/heat"
    creates "/etc/heat/policy.json"
  end
  venv_path = node[:heat][:use_virtualenv] ? "#{heat_path}/.venv" : nil
  venv_prefix = node[:heat][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil
end

include_recipe "#{@cookbook_name}::common"

directory "/var/cache/heat" do
  owner node[:heat][:user]
  group "root"
  mode 00755
  action :create
end unless node.platform == "suse"

env_filter = " AND rabbitmq_config_environment:rabbitmq-config-#{node[:heat][:rabbitmq_instance]}"
rabbits = search(:node, "roles:rabbitmq-server#{env_filter}") || []
if rabbits.length > 0
  rabbit = rabbits[0]
  rabbit = node if rabbit.name == node.name
else
  rabbit = node
end
rabbit_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(rabbit, "admin").address
Chef::Log.info("Rabbit server found at #{rabbit_address}")
rabbit_settings = {
  :address => rabbit_address,
  :port => rabbit[:rabbitmq][:port],
  :user => rabbit[:rabbitmq][:user],
  :password => rabbit[:rabbitmq][:password],
  :vhost => rabbit[:rabbitmq][:vhost]
}

env_filter = " AND keystone_config_environment:keystone-config-#{node[:heat][:keystone_instance]}"
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
keystone_service_user = node["heat"]["keystone_service_user"]
keystone_service_password = node["heat"]["keystone_service_password"]
Chef::Log.info("Keystone server found at #{keystone_host}")

my_admin_host = node[:fqdn]
# For the public endpoint, we prefer the public name. If not set, then we
# use the IP address except for SSL, where we always prefer a hostname
# (for certificate validation).
my_public_host = node[:crowbar][:public_name]
if my_public_host.nil? or my_public_host.empty?
  unless node[:heat][:api][:protocol] == "https"
    my_public_host = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
  else
    my_public_host = 'public.'+node[:fqdn]
  end
end

db_password = ''
if node.roles.include? "heat-server"
  # password is already created because common recipe comes
  # after the server recipe
  db_password = node[:heat][:db][:password]
else
  # pickup password to database from heat-server node
  node_controllers = search(:node, "roles:heat-server") || []
  if node_controllers.length > 0
    db_password = node_controllers[0][:heat][:db][:password]
  end
end


db_connection = "#{backend_name}://#{node[:heat][:db][:user]}:#{db_password}@#{sql_address}/#{node[:heat][:db][:database]}"


# do not run heat-db-setup since it wants to install packages and setup db passwords
execute "calling heat db sync" do
  command "python -m heat.db.sync"
  action :run
end


keystone_register "register heat user" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give heat user access" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

# Create Heat CloudFormation service
keystone_register "register Heat CloudFormation Service" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  service_name "heat-cfn"
  service_type "cloudformation"
  service_description "Heat CloudFormation Service"
  action :add_service
end

keystone_register "register heat Cfn endpoint" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  endpoint_service "heat"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:cfn_port]}/v1"
  endpoint_adminURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:cfn_port]}/v1"
  endpoint_internalURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:cfn_port]}/v1"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

# Create Heat service
keystone_register "register Heat Service" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  service_name "heat"
  service_type "orchestration"
  service_description "Heat Service"
  action :add_service
end

keystone_register "register heat endpoint" do
  protocol keystone_protocol
  host keystone_host
  port keystone_admin_port
  token keystone_token
  endpoint_service "heat"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{node[:heat][:api][:protocol]}://#{my_public_host}:#{node[:heat][:api][:port]}/v1/$(tenant_id)s"
  endpoint_adminURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:port]}/v1/$(tenant_id)s"
  endpoint_internalURL "#{node[:heat][:api][:protocol]}://#{my_admin_host}:#{node[:heat][:api][:port]}/v1/$(tenant_id)s"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

template "/etc/heat/heat-api.conf" do
    source "heat-api.conf.erb"
    owner node[:heat][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:heat][:debug],
      :verbose => node[:heat][:verbose],
      :rabbit_settings => rabbit_settings,
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :api_port => node[:heat][:api][:port],
      :database_connection => db_connection
    )
end

template "/etc/heat/heat-api-paste.ini" do
    source "heat-api-paste.ini.erb"
    owner node[:heat][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:heat][:debug],
      :verbose => node[:heat][:verbose],
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :api_port => node[:heat][:api][:port]
    )
end

service "heat-api" do
  service_name "openstack-heat-api" if node.platform == "suse"
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/heat/heat-api.conf]")
end

template "/etc/heat/heat-api-cfn.conf" do
    source "heat-api-cfn.conf.erb"
    owner node[:heat][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:heat][:debug],
      :verbose => node[:heat][:verbose],
      :rabbit_settings => rabbit_settings,
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :cfn_port => node[:heat][:api][:cfn_port]
    )
end

template "/etc/heat/heat-api-cfn-paste.ini" do
    source "heat-api-cfn-paste.ini.erb"
    owner node[:heat][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:heat][:debug],
      :verbose => node[:heat][:verbose],
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :cfn_port => node[:heat][:api][:cfn_port]
    )
end



service "heat-api-cfn" do
  service_name "openstack-heat-api-cfn" if node.platform == "suse"
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/heat/heat-api-cfn.conf]")
end

template "/etc/heat/heat-api-cloudwatch.conf" do
    source "heat-api-cloudwatch.conf.erb"
    owner node[:heat][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:heat][:debug],
      :verbose => node[:heat][:verbose],
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :cfn_port => node[:heat][:api][:cfn_port]
    )
end

service "heat-api-cloudwatch" do
  service_name "openstack-heat-api-cloudwatch" if node.platform == "suse"
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/heat/heat-api-cloudwatch.conf]")
end

template "/etc/heat/heat-engine.conf" do
    source "heat-engine.conf.erb"
    owner node[:heat][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:heat][:debug],
      :verbose => node[:heat][:verbose],
      :rabbit_settings => rabbit_settings,
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :cfn_port => node[:heat][:api][:cfn_port],
      :database_connection => db_connection
    )
end

service "heat-engine" do
  service_name "openstack-heat-engine" if node.platform == "suse"
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/heat/heat-engine.conf]")
end


node.save
