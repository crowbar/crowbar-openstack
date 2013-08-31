
env_filter = " AND keystone_config_environment:keystone-config-#{node[:heat][:keystone_instance]}"
keystones = search(:node, "recipes:keystone\\:\\:server#{env_filter}") || []
if keystones.length > 0
  keystone = keystones[0]
  keystone = node if keystone.name == node.name
else
  keystone = node
end

keystone_host = keystone[:fqdn]
keystone_protocol = keystone["keystone"]["api"]["protocol"]
keystone_token = keystone["keystone"]["service"]["token"]
keystone_admin_port = keystone["keystone"]["api"]["admin_port"]
keystone_service_port = keystone["keystone"]["api"]["service_port"]
keystone_service_tenant = keystone["keystone"]["service"]["tenant"]
keystone_service_user = node["heat"]["keystone_service_user"]
keystone_service_password = node["heat"]["keystone_service_password"]
Chef::Log.info("Keystone server found at #{keystone_host}")

sql_env_filter = " AND database_config_environment:database-config-#{node[:heat][:database_instance]}"
sqls = search(:node, "roles:database-server#{sql_env_filter}")
if sqls.length > 0
  sql = sqls[0]
  sql = node if sql.name == node.name
else
  sql = node
end

sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
Chef::Log.info("SQL server found at #{sql_address}")

include_recipe "database::client"
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
include_recipe "#{backend_name}::client"
include_recipe "#{backend_name}::python-client"


