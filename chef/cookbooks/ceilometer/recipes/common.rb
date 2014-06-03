
rabbit = get_instance('roles:rabbitmq-server')
Chef::Log.info("Rabbit server found at #{rabbit[:rabbitmq][:address]}")
rabbit_settings = {
  :address => rabbit[:rabbitmq][:address],
  :port => rabbit[:rabbitmq][:port],
  :user => rabbit[:rabbitmq][:user],
  :password => rabbit[:rabbitmq][:password],
  :vhost => rabbit[:rabbitmq][:vhost]
}

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:ceilometer][:use_mongodb]
  db_host = nil
  db_hosts = search_env_filtered(:node, "roles:ceilometer-server")
  if node[:ceilometer][:ha][:server][:enabled]
    # Currently, we only setup mongodb non-HA on the first node
    db_host = db_hosts.select { |n| CrowbarPacemakerHelper.is_cluster_founder?(n) }.first
  end
  db_host ||= db_hosts.first || node

  mongodb_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
  db_connection = "mongodb://#{mongodb_ip}:27017/ceilometer"
else
  sql = get_instance('roles:database-server')

  sql_address = CrowbarDatabaseHelper.get_listen_address(sql)
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

if node[:ceilometer][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:ceilometer][:ha][:ports][:api]
else
  bind_host = "0.0.0.0"
  bind_port = node[:ceilometer][:api][:port]
end

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    owner node[:ceilometer][:user]
    group node[:ceilometer][:group]
    mode "0640"
    variables(
      :debug => node[:ceilometer][:debug],
      :verbose => node[:ceilometer][:verbose],
      :rabbit_settings => rabbit_settings,
      :keystone_settings => keystone_settings,
      :bind_host => bind_host,
      :bind_port => bind_port,
      :metering_secret => node[:ceilometer][:metering_secret],
      :database_connection => db_connection,
      :node_hostname => node['hostname']
    )
end

template "/etc/ceilometer/pipeline.yaml" do
  source "pipeline.yaml.erb"
  owner node[:ceilometer][:user]
  group node[:ceilometer][:group]
  mode "0640"
  variables({
      :meters_interval => node[:ceilometer][:meters_interval],
      :cpu_interval => node[:ceilometer][:cpu_interval]
  })
end
