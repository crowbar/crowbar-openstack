#
# Cookbook Name:: oat
# Recipe:: server
#
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['oat']['db']['password'] = secure_password
node.set_unless['oat']['password'] = secure_password

Chef::Log.info("Configuring OAT to use MySQL backend")

include_recipe "mysql::client"

env_filter = " AND mysql_config_environment:mysql-config-#{node[:inteltxt][:mysql_instance]}"
mysqls = search(:node, "roles:mysql-server#{env_filter}") || []
if mysqls.length > 0
    mysql = mysqls[0]
    mysql = node if mysql.name == node.name
else
    mysql = node
end

mysql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(mysql, "admin").address if mysql_address.nil?
Chef::Log.info("Mysql server found at #{mysql_address}")

cf = cookbook_file "/root/create_tables.sql" do
  source "create_tables.sql"
  action :nothing
end
cf.run_action(:create)

execute "create_tables_for_oat" do
  command "mysql -u #{node[:inteltxt][:db][:user]} -p#{node[:inteltxt][:db][:password]} -h #{mysql_address} #{node[:inteltxt][:db][:database]} < /root/create_tables.sql"
  ignore_failure true
  action :nothing
end

mysql_database "create #{node[:inteltxt][:db][:database]} oat database" do
    host    mysql_address
    username "db_maker"
    password mysql[:mysql][:db_maker_password]
    database node[:inteltxt][:db][:database]
    action :create_db
end

mysql_database "create oat database user #{node[:inteltxt][:db][:user]}" do
    host    mysql_address
    username "db_maker"
    password mysql[:mysql][:db_maker_password]
    database node[:inteltxt][:db][:database]
    action :query
    sql "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER on #{node[:inteltxt][:db][:database]}.* to '#{node[:inteltxt][:db][:user]}'@'%' IDENTIFIED BY '#{node[:inteltxt][:db][:password]}';"
    notifies :run, resources(:execute => "create_tables_for_oat"), :immediately
end

package "dbconfig-common"

template "/etc/dbconfig-common/oat-appraiser.conf" do
  source "oat-appraiser.conf.erb"
  variables(:db_user => node[:inteltxt][:db][:user],
            :db_pass => node[:inteltxt][:db][:password],
            :db_name => node[:inteltxt][:db][:database]
           )
end

[ { "k" => "password", "t" => "password", "v" => node[:inteltxt][:password] },
  { "k" => "hostname", "t" => "string", "v" => node[:fqdn] },
].each { |x|
  execute "set_#{x['k']}_for_oat-appraiser-installation" do
    command "echo oat-appraiser oat-appraiser/#{x['k']} #{x['t']} #{x['v']} | debconf-set-selections"
  end
}

ENV['DB_CONFIGURED'] = 'true'
ENV['DEBIAN_FRONTEND'] = 'noninteractive'
package "oat-appraiser" do
  options "--force-yes"
end

# just in case if post-inst script failed to create keys
execute "create_keystore" do
  command "/usr/share/oat-appraiser/scripts/generate-keystores #{node[:fqdn]} #{node[:inteltxt][:password]} 2>&1 >/dev/null"
  ignore_failure true
  not_if { File.exists? "/var/lib/oat-appraiser/Certificate/keystore.jks" } 
end

execute "restart_tomcat6_service" do
  command "invoke-rc.d tomcat6 restart"
  ignore_failure true
  action :nothing
end

execute "restart_apache2_service" do
  command "invoke-rc.d apache2 restart"
  ignore_failure true
  action :nothing
end

execute "fix_db_hostname" do
  command "find /etc/oat-appraiser -type f -exec sed -i 's/localhost/#{mysql_address}/' {} \\;"
  only_if "grep -q -r localhost /etc/oat-appraiser/"
  ignore_failure true
  notifies :run, resources(:execute => "restart_tomcat6_service")
  notifies :run, resources(:execute => "restart_apache2_service")
end

