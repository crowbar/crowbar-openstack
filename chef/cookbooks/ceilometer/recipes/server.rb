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

ha_enabled = node[:ceilometer][:ha][:server][:enabled]

if node[:ceilometer][:use_mongodb]
  if !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)
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

    mongodb_address  = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

    template mongo_conf do
      mode 0644
      source "mongodb.conf.erb"
      variables(:listen_addr => mongodb_address)
      notifies :restart, "service[#{mongo_service}]", :immediately
    end

    service mongo_service do
      supports :status => true, :restart => true
      action [:enable, :start]
    end
  else
    # HA is enabled, and we're not the cluster founder
    # Currently, we only setup mongodb non-HA on the first node, so wait for this one...
    db_hosts = search_env_filtered(:node, "roles:ceilometer-server")
    db_host = db_hosts.select { |n| CrowbarPacemakerHelper.is_cluster_founder?(n) }.first
    mongodb_address  = Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
  end

  # wait for mongodb start (ceilometer services need it running)
  ruby_block "wait for mongodb start" do
    block do
      require 'timeout'
      begin
        Timeout.timeout(60) do
          while ! ::Kernel.system("mongo #{mongodb_address} --quiet < /dev/null &> /dev/null")
            Chef::Log.debug("mongodb still not reachable")
            sleep(2)
          end
        end
      rescue Timeout::Error
        Chef::Log.warn("mongodb does not seem to be responding 1 minute after start")
      end
    end # block
  end # ruby_block

else
  sql = get_instance('roles:database-server')
  include_recipe "database::client"
  backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
  include_recipe "#{backend_name}::client"
  include_recipe "#{backend_name}::python-client"

  db_provider = Chef::Recipe::Database::Util.get_database_provider(sql)
  db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql)
  privs = Chef::Recipe::Database::Util.get_default_priviledges(sql)

  sql_address = CrowbarDatabaseHelper.get_listen_address(sql)
  Chef::Log.info("Database server found at #{sql_address}")

  db_conn = { :host => sql_address,
              :username => "db_maker",
              :password => sql[:database][:db_maker_password] }

  crowbar_pacemaker_sync_mark "wait-ceilometer_database"

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
    
  crowbar_pacemaker_sync_mark "create-ceilometer_database"
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
end

include_recipe "#{@cookbook_name}::common"

directory "/var/cache/ceilometer" do
  owner node[:ceilometer][:user]
  group "root"
  mode 00755
  action :create
end unless node.platform == "suse"

keystone_settings = CeilometerHelper.keystone_settings(node)

my_admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
my_public_host = CrowbarHelper.get_host_for_public_url(node, node[:ceilometer][:api][:protocol] == "https", ha_enabled)

crowbar_pacemaker_sync_mark "wait-ceilometer_db_sync"

execute "calling ceilometer-dbsync" do
  command "#{venv_prefix}ceilometer-dbsync"
  action :run
  user node[:ceilometer][:user]
  group node[:ceilometer][:group]
  # On SUSE, we only need this when HA is enabled as the init script is doing
  # this (but that creates races with HA)
  only_if { node.platform != "suse" || ha_enabled }
end

crowbar_pacemaker_sync_mark "create-ceilometer_db_sync"

service "ceilometer-collector" do
  service_name node[:ceilometer][:collector][:service_name]
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :enable, :start ]
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
  subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

service "ceilometer-api" do
  service_name node[:ceilometer][:api][:service_name]
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :enable, :start ]
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
  subscribes :restart, resources("template[/etc/ceilometer/pipeline.yaml]")
  provider Chef::Provider::CrowbarPacemakerService if ha_enabled
end

if ha_enabled
  log "HA support for ceilometer is enabled"
  include_recipe "ceilometer::server_ha"
else
  log "HA support for ceilometer is disabled"
end

crowbar_pacemaker_sync_mark "wait-ceilometer_register"

keystone_register "register ceilometer user" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  user_name keystone_settings['service_user']
  user_password keystone_settings['service_password']
  tenant_name keystone_settings['service_tenant']
  action :add_user
end

keystone_register "give ceilometer user access" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  user_name keystone_settings['service_user']
  tenant_name keystone_settings['service_tenant']
  role_name "admin"
  action :add_access
end

env_filter = " AND ceilometer_config_environment:#{node[:ceilometer][:config][:environment]}"
swift_middlewares = search(:node, "roles:ceilometer-swift-proxy-middleware#{env_filter}") || []
unless swift_middlewares.empty?
  keystone_register "give ceilometer user ResellerAdmin role" do
    protocol keystone_settings['protocol']
    host keystone_settings['internal_url_host']
    port keystone_settings['admin_port']
    token keystone_settings['admin_token']
    user_name keystone_settings['service_user']
    tenant_name keystone_settings['service_tenant']
    role_name "ResellerAdmin"
    action :add_access
  end
end

# Create ceilometer service
keystone_register "register ceilometer service" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  service_name "ceilometer"
  service_type "metering"
  service_description "Openstack Collector Service"
  action :add_service
end

keystone_register "register ceilometer endpoint" do
  protocol keystone_settings['protocol']
  host keystone_settings['internal_url_host']
  port keystone_settings['admin_port']
  token keystone_settings['admin_token']
  endpoint_service "ceilometer"
  endpoint_region "RegionOne"
  endpoint_publicURL "#{node[:ceilometer][:api][:protocol]}://#{my_public_host}:#{node[:ceilometer][:api][:port]}/"
  endpoint_adminURL "#{node[:ceilometer][:api][:protocol]}://#{my_admin_host}:#{node[:ceilometer][:api][:port]}/"
  endpoint_internalURL "#{node[:ceilometer][:api][:protocol]}://#{my_admin_host}:#{node[:ceilometer][:api][:port]}/"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end

crowbar_pacemaker_sync_mark "create-ceilometer_register"

node.save
