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

unless node[:quantum][:use_gitrepo]
  package "quantum" do
    action :install
  end
else
  puts "git_refspec = #{node[:quantum][:git_refspec]}"
  pfs_and_install_deps(@cookbook_name)
  link_service @cookbook_name do
    bin_name "quantum-server"
  end
  create_user_and_dirs(@cookbook_name)
#  pfs_and_install_deps "quantum" do
#    cookbook "quantum"
#    cnode quantum
#  end
end



service "quantum" do
  supports :status => true, :restart => true
  action :enable
end

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['quantum']['db']['password'] = secure_password

if node[:quantum][:sql_engine] == "mysql"
    Chef::Log.info("Configuring Quantum to use MySQL backend")

    include_recipe "mysql::client"

    package "python-mysqldb" do
        action :install
    end

    env_filter = " AND mysql_config_environment:mysql-config-#{node[:quantum][:mysql_instance]}"
    mysqls = search(:node, "roles:mysql-server#{env_filter}") || []
    if mysqls.length > 0
        mysql = mysqls[0]
        mysql = node if mysql.name == node.name
    else
        mysql = node
    end

    mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
    Chef::Log.info("Mysql server found at #{mysql_address}")
    
    # Create the Quantum Database
    mysql_database "create #{node[:quantum][:db][:database]} database" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:quantum][:db][:database]
        action :create_db
    end

    mysql_database "create dashboard database user" do
        host    mysql_address
        username "db_maker"
        password mysql[:mysql][:db_maker_password]
        database node[:quantum][:db][:database]
        action :query
        sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{node[:quantum][:db][:database]}.* to '#{node[:quantum][:db][:user]}'@'%' IDENTIFIED BY '#{node[:quantum][:db][:password]}';"
    end
    sql_connection = "mysql://#{node[:quantum][:db][:user]}:#{node[:quantum][:db][:password]}@#{mysql_address}/#{node[:quantum][:db][:database]}"
elsif node[:quantum][:sql_engine] == "sqlite"
    Chef::Log.info("Configuring Quantum to use SQLite backend")
    sql_connection = "sqlite:////var/lib/quantum/quantum.db"
    file "/var/lib/quantum/quantum.db" do
        owner "quantum"
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

template "/etc/quantum/quantum.conf" do
    source "quantum.conf.erb"
    mode "0644"
    owner "quantum"
    variables(
      :sql_connection => sql_connection,
      :sql_idle_timeout => node[:quantum][:sql][:idle_timeout],
      :sql_min_pool_size => node[:quantum][:sql][:min_pool_size],
      :sql_max_pool_size => node[:quantum][:sql][:max_pool_size],
      :sql_pool_timeout => node[:quantum][:sql][:pool_timeout],
      :debug => node[:quantum][:debug],
      :verbose => node[:quantum][:verbose],
      :admin_token => node[:quantum][:service][:token],
      :service_port => node[:quantum][:api][:service_port], # Compute port
      :service_host => node[:quantum][:api][:service_host],
      :use_syslog => node[:quantum][:use_syslog],
      :rabbit_settings => rabbit_settings

    )
    notifies :restart, resources(:service => "quantum"), :immediately
end

env_filter = " AND keystone_config_environment:keystone-config-#{node[:quantum][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end


keystone_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(keystone, "admin").address if keystone_address.nil?
keystone_token = keystone["keystone"]["service"]["token"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["quantum"]["service_user"]
keystone_service_password = node["quantum"]["service_password"]
Chef::Log.info("Keystone server found at #{keystone_address}")
template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner "quantum"
  group "root"
  mode "0640"
  variables(
    :keystone_ip_address => keystone_address,
    :keystone_admin_token => keystone_token,
    :keystone_service_port => keystone_service_port,
    :keystone_service_tenant => keystone_service_tenant,
    :keystone_service_user => keystone_service_user,
    :keystone_service_password => keystone_service_password,
    :keystone_admin_port => keystone_admin_port
  )
  notifies :restart, resources(:service => "quantum"), :immediately
end




#execute "quantum-manage db_sync" do
#  action :run
#end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

node[:quantum][:monitor] = {} if node[:quantum][:monitor].nil?
node[:quantum][:monitor][:svcs] = [] if node[:quantum][:monitor][:svcs].nil?
node[:quantum][:monitor][:svcs] <<["quantum"]
node.save


keystone_register "quantum api wakeup keystone" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  action :wakeup
end

keystone_register "register quantum user" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  user_password keystone_service_password
  tenant_name keystone_service_tenant
  action :add_user
end

keystone_register "give quantum user access" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  user_name keystone_service_user
  tenant_name keystone_service_tenant
  role_name "admin"
  action :add_access
end

keystone_register "register quantum service" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  service_name "quantum"
  service_type "network"
  service_description "Openstack Quantum Service"
  action :add_service
end

keystone_register "register quantum endpoint" do
  host keystone_address
  port keystone_admin_port
  token keystone_token
  endpoint_service "quantum"
  endpoint_region "RegionOne"
  endpoint_publicURL "http://#{pub_ipaddress}:9696/"
  endpoint_adminURL "http://#{my_ipaddress}:9696/"
  endpoint_internalURL "http://#{my_ipaddress}:9696/"
#  endpoint_global true
#  endpoint_enabled true
  action :add_endpoint_template
end
