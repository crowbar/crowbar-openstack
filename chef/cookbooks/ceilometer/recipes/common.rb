include_recipe "apache2"

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:ceilometer][:use_mongodb]
  db_connection = CeilometerHelper.mongodb_connection_string(node)
else
  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

  db_auth = node[:ceilometer][:db].dup
  unless node.roles.include? "ceilometer-server"
    # pickup password to database from ceilometer-server node
    node_controllers = node_search_with_cache("roles:ceilometer-server")
    if node_controllers.length > 0
      db_auth[:password] = node_controllers[0][:ceilometer][:db][:password]
    end
  end

  db_connection = fetch_database_connection_string(db_auth)
end

is_compute_agent = node.roles.include?("ceilometer-agent") && node.roles.any? { |role| /^nova-compute-/ =~ role }
is_swift_proxy = node.roles.include?("ceilometer-swift-proxy-middleware") && node.roles.include?("swift-proxy")

# Find hypervisor inspector
hypervisor_inspector = nil
libvirt_type = nil
if is_compute_agent
  if node.roles.include?("nova-compute-vmware")
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
  bind_host = node[:ceilometer][:api][:host]
  bind_port = node[:ceilometer][:api][:port]
end

metering_time_to_live = node[:ceilometer][:database][:metering_time_to_live]
event_time_to_live = node[:ceilometer][:database][:event_time_to_live]

# We store the value of time to live in days, but config file expects
# seconds
if metering_time_to_live > 0
  metering_time_to_live = metering_time_to_live * 3600 * 24
end
if event_time_to_live > 0
  event_time_to_live = event_time_to_live * 3600 * 24
end

template node[:ceilometer][:config_file] do
    source "ceilometer.conf.erb"
    owner "root"
    group node[:ceilometer][:group]
    mode "0640"
    variables(
      debug: node[:ceilometer][:debug],
      verbose: node[:ceilometer][:verbose],
      rabbit_settings: fetch_rabbitmq_settings,
      keystone_settings: keystone_settings,
      bind_host: bind_host,
      bind_port: bind_port,
      metering_secret: node[:ceilometer][:metering_secret],
      database_connection: db_connection,
      node_hostname: node["hostname"],
      hypervisor_inspector: hypervisor_inspector,
      libvirt_type: libvirt_type,
      metering_time_to_live: metering_time_to_live,
      event_time_to_live: event_time_to_live,
      default_api_return_limit: node[:ceilometer][:api][:default_return_limit]
    )
    if is_compute_agent
      notifies :restart, "service[nova-compute]"
    end
    if is_swift_proxy
      notifies :restart, "service[swift-proxy]"
    end
    notifies :reload, resources(service: "apache2")
end

template "/etc/ceilometer/pipeline.yaml" do
  source "pipeline.yaml.erb"
  owner "root"
  group "root"
  mode "0644"
  variables({
      meters_interval: node[:ceilometer][:meters_interval],
      cpu_interval: node[:ceilometer][:cpu_interval],
      disk_interval: node[:ceilometer][:disk_interval],
      network_interval: node[:ceilometer][:network_interval]
  })
  if is_compute_agent
    notifies :restart, "service[nova-compute]"
  end
  if is_swift_proxy
    notifies :restart, "service[swift-proxy]"
  end
end
