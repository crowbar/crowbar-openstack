
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

db_hosts = search(:node, "roles:ceilometer-server") || []
if db_hosts.length > 0
  db_host = db_hosts.first
  db_host = node if db_host.name == node.name
else
  db_host = node
end

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    mode "0644"
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
      :db_host => db_host.name
    )
end

