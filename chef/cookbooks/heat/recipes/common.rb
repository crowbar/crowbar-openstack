
sql = get_instance('roles:database-server')
sql_address = CrowbarDatabaseHelper.get_listen_address(sql)
Chef::Log.info("Database server found at #{sql_address}")

include_recipe "database::client"
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
include_recipe "#{backend_name}::client"
include_recipe "#{backend_name}::python-client"


