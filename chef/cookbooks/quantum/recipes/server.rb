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

package "quantum" do
  action :install
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

template "/etc/quantum/quantum.conf" do
    source "quantum.conf.erb"
    mode "0644"
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
      :use_syslog => node[:quantum][:use_syslog]
    )
    notifies :restart, resources(:service => "quantum"), :immediately
end

execute "quantum-manage db_sync" do
  action :run
end

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
pub_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address rescue my_ipaddress

node[:quantum][:monitor] = {} if node[:quantum][:monitor].nil?
node[:quantum][:monitor][:svcs] = [] if node[:quantum][:monitor][:svcs].nil?
node[:quantum][:monitor][:svcs] <<["quantum"]
node.save
