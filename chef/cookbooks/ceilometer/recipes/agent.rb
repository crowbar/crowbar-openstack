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

package "mongodb" do
  action :install
end

unless node[:ceilometer][:use_gitrepo]
  package "ceilometer-agent-compute" do
    action :install
  end
  package "ceilometer-agent-central" do
    action :install
  end
else
  ceilometer_path = "/opt/ceilometer"
  pfs_and_install_deps(@cookbook_name)
  link_service @cookbook_name do
    bin_name "ceilometer-agent"
  end
  create_user_and_dirs(@cookbook_name) 
#  execute "cp_policy.json" do
#    command "cp #{ceilometer_path}/etc/policy.json /etc/ceilometer"
#    creates "/etc/ceilometer/policy.json"
#  end
end

service "ceilometer" do
  supports :status => true, :restart => true
  action :enable
end

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['ceilometer']['db']['password'] = secure_password

if node[:ceilometer][:sql_engine] == "mysql"
    Chef::Log.info("Configuring Ceilometer to use MySQL backend")

    include_recipe "mysql::client"

    package "python-mysqldb" do
        action :install
    end

    env_filter = " AND mysql_config_environment:mysql-config-#{node[:ceilometer][:mysql_instance]}"
    mysqls = search(:node, "roles:mysql-server#{env_filter}") || []
    if mysqls.length > 0
        mysql = mysqls[0]
        mysql = node if mysql.name == node.name
    else
        mysql = node
    end

    mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
    Chef::Log.info("Mysql server found at #{mysql_address}")
    
    # Create the Ceilometer Database
#    mysql_database "create #{node[:ceilometer][:db][:database]} database" do
#        host    mysql_address
#        username "db_maker"
#        password mysql[:mysql][:db_maker_password]
#        database node[:ceilometer][:db][:database]
#        action :create_db
#    end

#    mysql_database "create database user" do
#        host    mysql_address
#        username "db_maker"
#        password mysql[:mysql][:db_maker_password]
#        database node[:ceilometer][:db][:database]
#        action :query
#        sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{node[:ceilometer][:db][:database]}.* to '#{node[:ceilometer][:db][:user]}'@'%' IDENTIFIED BY '#{node[:ceilometer][:db][:password]}';"
#    end
    sql_connection = "mysql://#{node[:ceilometer][:db][:user]}:#{node[:ceilometer][:db][:password]}@#{mysql_address}/#{node[:ceilometer][:db][:database]}"
elsif node[:ceilometer][:sql_engine] == "sqlite"
    Chef::Log.info("Configuring Ceilometer to use SQLite backend")
    sql_connection = "sqlite:////var/lib/ceilometer/ceilometer.db"
    file "/var/lib/ceilometer/ceilometer.db" do
        owner "ceilometer"
        action :create_if_missing
    end
end

rabbits = search(:node, "recipes:nova\\:\\:rabbit") || []
if rabbits.length > 0
  rabbit = rabbits[0]
  rabbit = node if rabbit.name == node.name
else
  rabbit = node
end
rabbit_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(rabbit, "admin").address
Chef::Log.info("Rabbit server found at #{rabbit_address}")
if rabbit[:nova]
  #agordeev:
  # rabbit settings will work only after nova proposal be deployed
  # and cinder services will be restarted then
  rabbit_settings = {
    :address => rabbit_address,
    :port => rabbit[:nova][:rabbit][:port],
    :user => rabbit[:nova][:rabbit][:user],
    :password => rabbit[:nova][:rabbit][:password],
    :vhost => rabbit[:nova][:rabbit][:vhost]
  }
else
  rabbit_settings = nil
end

keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_token = keystone["keystone"]["service"]["token"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node[:glance][:service_user]
keystone_service_password = node[:glance][:service_password]
Chef::Log.info("Keystone server found at #{keystone_address}")

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    mode "0644"
    variables(
      :sql_connection => sql_connection,
      :sql_idle_timeout => node[:ceilometer][:sql][:idle_timeout],
      :sql_min_pool_size => node[:ceilometer][:sql][:min_pool_size],
      :sql_max_pool_size => node[:ceilometer][:sql][:max_pool_size],
      :sql_pool_timeout => node[:ceilometer][:sql][:pool_timeout],
      :debug => node[:ceilometer][:debug],
      :verbose => node[:ceilometer][:verbose],
      :use_syslog => node[:ceilometer][:use_syslog],
      :rabbit_settings => rabbit_settings,
      :keystone_address => keystone_address,
      :keystone_auth_token => keystone_token,
      :keystone_service_port => keystone_service_port,
      :keystone_service_user => keystone_service_user,
      :keystone_service_password => keystone_service_password,
      :keystone_service_tenant => keystone_service_tenant,
      :keystone_admin_port => keystone_admin_port
    )
    notifies :restart, resources(:service => "ceilometer"), :immediately
end

#execute "ceilometer-manage db_sync" do
#  action :run
#end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

# Create ceilometer service
ceilometer_register "register ceilometer service" do
  host my_ipaddress
  port node[:ceilometer][:api][:port]
  service_name "ceilometer"
  service_type "collector"
  service_description "Openstack Collector Service"
  action :add_service
end

node.save
