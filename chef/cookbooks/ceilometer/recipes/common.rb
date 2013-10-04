
env_filter = " AND rabbitmq_config_environment:rabbitmq-config-#{node[:ceilometer][:rabbitmq_instance]}"
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

if node[:ceilometer][:use_mongodb]
  db_hosts = search(:node, "roles:ceilometer-server") || []
  if db_hosts.length > 0
    db_host = db_hosts.first
    db_host = node if db_host.name == node.name
  else
    db_host = node
  end
  mongodb_ip=Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
  db_connection = "mongodb://#{mongodb_ip}:27017/ceilometer"
else
  sql_env_filter = " AND database_config_environment:database-config-#{node[:ceilometer][:database_instance]}"
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
  if node.roles.include? "ceilometer-server"
    # password is already created because common recipe comes
    # after the server recipe
    db_password = node[:ceilometer][:db][:password]
  else
    # pickup password to database from ceilometer-server node
    node_controllers = search(:node, "roles:ceilometer-server") || []
    if node_controllers.length > 0
      db_password = node_controllers[0][:ceilometer][:db][:password]
    end
  end

  db_connection = "#{backend_name}://#{node[:ceilometer][:db][:user]}:#{db_password}@#{sql_address}/#{node[:ceilometer][:db][:database]}"
end

metering_secret = ''
if node.roles.include? "ceilometer-server"
  # secret is already created because common recipe comes
  # after the server recipe
  metering_secret = node[:ceilometer][:metering_secret]
else
  # pickup secret from ceilometer-server node
  node_controllers = search(:node, "roles:ceilometer-server") || []
  if node_controllers.length > 0
    metering_secret = node_controllers[0][:ceilometer][:metering_secret]
  end
end

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    owner node[:ceilometer][:user]
    group "root"
    mode "0640"
    variables(
      :debug => node[:ceilometer][:debug],
      :verbose => node[:ceilometer][:verbose],
      :rabbit_settings => rabbit_settings,
      :keystone_protocol => keystone_protocol,
      :keystone_host => keystone_host,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port,
      :api_port => node[:ceilometer][:api][:port],
      :metering_secret => metering_secret,
      :database_connection => db_connection,
      :node_hostname => node['hostname']
    )
end

