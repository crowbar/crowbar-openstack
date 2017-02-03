
keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

if node[:ceilometer][:use_mongodb]
  db_connection = nil

  if node[:ceilometer][:ha][:server][:enabled]
    db_hosts = node_search_with_cache("roles:ceilometer-server").select do |n|
      n[:ceilometer][:ha][:mongodb][:replica_set][:member] rescue false
    end
    unless db_hosts.empty?
      mongodb_servers = db_hosts.map { |s| "#{Chef::Recipe::Barclamp::Inventory.get_network_by_type(s, "admin").address}:#{s[:ceilometer][:mongodb][:port]}" }
      db_connection = "mongodb://#{mongodb_servers.sort.join(',')}/ceilometer?replicaSet=#{node[:ceilometer][:ha][:mongodb][:replica_set][:name]}"
    end
  end

  # if this is a cluster, but the replica set member attribute hasn't
  # been set on any node (yet), we just fallback to using the first
  # ceilometer-server node
  if db_connection.nil?
    db_hosts = node_search_with_cache("roles:ceilometer-server")
    db_host = db_hosts.first || node
    mongodb_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
    db_connection = "mongodb://#{mongodb_ip}:#{db_host[:ceilometer][:mongodb][:port]}/ceilometer"
  end
else
  db_settings = fetch_database_settings

  include_recipe "database::client"
  include_recipe "#{db_settings[:backend_name]}::client"
  include_recipe "#{db_settings[:backend_name]}::python-client"

  db_password = ""
  if node.roles.include? "ceilometer-server"
    # password is already created because common recipe comes
    # after the server recipe
    db_password = node[:ceilometer][:db][:password]
  else
    # pickup password to database from ceilometer-server node
    node_controllers = node_search_with_cache("roles:ceilometer-server")
    if node_controllers.length > 0
      db_password = node_controllers[0][:ceilometer][:db][:password]
    end
  end

  db_connection = "#{db_settings[:url_scheme]}://#{node[:ceilometer][:db][:user]}:#{db_password}@#{db_settings[:address]}/#{node[:ceilometer][:db][:database]}"
end

is_compute_agent = node.roles.include?("ceilometer-agent") && node.roles.any? { |role| /^nova-compute-/ =~ role }
is_swift_proxy = node.roles.include?("ceilometer-swift-proxy-middleware") && node.roles.include?("swift-proxy")

# Find hypervisor inspector
hypervisor_inspector = nil
libvirt_type = nil
if is_compute_agent
  if node.roles.include?("nova-compute-vmware")
    hypervisor_inspector = "vmware"
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

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    owner "root"
    group node[:ceilometer][:group]
    mode "0640"
    variables(
      debug: node[:ceilometer][:debug],
      verbose: node[:ceilometer][:verbose],
      rabbit_settings: fetch_rabbitmq_settings,
      keystone_settings: keystone_settings,
      internal_auth_url_v2: KeystoneHelper.versioned_service_URL(
        keystone_settings["protocol"], keystone_settings["internal_url_host"],
        keystone_settings["service_port"], "2.0"),
      bind_host: bind_host,
      bind_port: bind_port,
      metering_secret: node[:ceilometer][:metering_secret],
      database_connection: db_connection,
      node_hostname: node["hostname"],
      hypervisor_inspector: hypervisor_inspector,
      libvirt_type: libvirt_type,
      metering_time_to_live: metering_time_to_live,
      event_time_to_live: event_time_to_live,
      alarm_threshold_evaluation_interval: node[:ceilometer][:alarm_threshold_evaluation_interval]
    )
    if is_compute_agent
      notifies :restart, "service[nova-compute]"
    end
    if is_swift_proxy
      notifies :restart, "service[swift-proxy]"
    end
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
