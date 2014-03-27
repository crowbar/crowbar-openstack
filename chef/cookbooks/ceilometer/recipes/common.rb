
keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:ceilometer][:use_mongodb]
  if node[:ceilometer][:ha][:server][:enabled]
    db_hosts = search(:node, "ceilometer_ha_mongodb_replica_set_member:true")
    instances = db_hosts.map {|s| "#{s.address.addr}:#{s[:ceilometer][:mongodb][:port]}"}
    db_connection = "mongodb://#{instances.join(',')}/ceilometer?replicaSet=#{node[:ceilometer][:ha][:mongodb][:replica_set][:name]}"
  else
    db_hosts = search_env_filtered(:node, "roles:ceilometer-server")
    db_host ||= db_hosts.first || node
    mongodb_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
    db_connection = "mongodb://#{mongodb_ip}:#{db_host[:ceilometer][:mongodb][:port]}/ceilometer"
  end
else
  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

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

  db_connection = "#{db_settings[:url_scheme]}://#{node[:ceilometer][:db][:user]}:#{db_password}@#{db_settings[:address]}/#{node[:ceilometer][:db][:database]}"
end

# Find hypervisor inspector
hypervisor_inspector = nil
libvirt_type = nil
if node.roles.include?("ceilometer-agent")
  if node.roles.include?("nova-multi-compute-vmware")
    hypervisor_inspector = "vsphere"
  else
    hypervisor_inspector = "libvirt"
    libvirt_type = node[:nova][:libvirt_type]
  end
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
      :rabbit_settings => fetch_rabbitmq_settings,
      :keystone_settings => keystone_settings,
      :bind_host => bind_host,
      :bind_port => bind_port,
      :metering_secret => node[:ceilometer][:metering_secret],
      :database_connection => db_connection,
      :node_hostname => node['hostname'],
      :hypervisor_inspector => hypervisor_inspector,
      :libvirt_type => libvirt_type,
      :alarm_threshold_evaluation_interval => node[:ceilometer][:alarm_threshold_evaluation_interval]
    )
    if node.roles.include?("ceilometer-agent")
      notifies :restart, "service[nova-compute]"
    end
end

template "/etc/ceilometer/pipeline.yaml" do
  source "pipeline.yaml.erb"
  owner node[:ceilometer][:user]
  group node[:ceilometer][:group]
  mode "0640"
  variables({
      :meters_interval => node[:ceilometer][:meters_interval],
      :cpu_interval => node[:ceilometer][:cpu_interval],
      :disk_interval => node[:ceilometer][:disk_interval],
      :network_interval => node[:ceilometer][:network_interval]
  })
  if node.roles.include?("ceilometer-agent")
    notifies :restart, "service[nova-compute]"
  end
end
