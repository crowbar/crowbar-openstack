# database creation for manila

db_settings = fetch_database_settings
include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

# Create the Manila Database
database "create #{node[:manila][:db][:database]} database" do
  connection db_settings[:connection]
  database_name node[:manila][:db][:database]
  provider db_settings[:provider]
  action :create
end

database_user "create manila database user" do
  host "%"
  connection db_settings[:connection]
  username node[:manila][:db][:user]
  password node[:manila][:db][:password]
  provider db_settings[:user_provider]
  action :create
end

database_user "grant database access for manila database user" do
  connection db_settings[:connection]
  username node[:manila][:db][:user]
  password node[:manila][:db][:password]
  database_name node[:manila][:db][:database]
  host "%"
  privileges db_settings[:privs]
  provider db_settings[:user_provider]
  action :grant
end
