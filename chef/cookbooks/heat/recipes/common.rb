
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

sql_env_filter = " AND database_config_environment:database-config-#{node[:heat][:database_instance]}"
sqls = search(:node, "roles:database-server#{sql_env_filter}")
if sqls.length > 0
  sql = sqls[0]
  sql = node if sql.name == node.name
else
  sql = node
end

sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
Chef::Log.info("SQL server found at #{sql_address}")

include_recipe "database::client"
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
include_recipe "#{backend_name}::client"
include_recipe "#{backend_name}::python-client"

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
