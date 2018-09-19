databases = []
commands = []
# The "barclamp" parameter doesn't really matter here, we want to use the same
# instance for all databases.
db_settings = CrowbarOpenStackHelper.database_settings(node, "mysql")
psql_settings = CrowbarOpenStackHelper.database_settings(node, "postgresql")
CrowbarDatabaseHelper.roles_using_database.each do |role|
  role_migration_data = CrowbarDatabaseHelper.role_migration_data(role)
  barclamp = role_migration_data["barclamp"]

  # Find a node with this role even if the recipe was executed from another one
  # e.g. one of the database nodes.
  role_node = CrowbarOpenStackHelper.get_node(node, role, barclamp, "default")

  # Role not found on any node? Skip it completely.
  next if role_node.nil?

  db = if role == "ec2-api"
    role_node[barclamp]["ec2-api"]["db"]
  else
    role_node[barclamp]["db"]
  end
  db_conf_sections = {}
  db_connection_key = "connection"
  connection = CrowbarOpenStackHelper.database_connection_string(db_settings, db)
  databases << { db: db, url: connection }
  Chef::Log.info("connection string: #{connection}")
  db_conf_sections["database"] = connection

  # The nova-controller role creates more than one database
  if role == "nova-controller"
    connection = CrowbarOpenStackHelper.database_connection_string(db_settings,
      role_node[barclamp]["api_db"])
    databases << { db: role_node[barclamp]["api_db"], url: connection }
    Chef::Log.info("connection string: #{connection}")
    db_conf_sections["api_database"] = connection
    connection = CrowbarOpenStackHelper.database_connection_string(db_settings,
      role_node[barclamp]["placement_db"])
    databases << { db: role_node[barclamp]["placement_db"], url: connection }
    Chef::Log.info("connection string: #{connection}")
    db_conf_sections["placement_database"] = connection
  end
  # Barbican uses non-standard db config structure
  if role == "barbican-controller"
    db_conf_sections = { "DEFAULT" => connection }
    db_connection_key = "sql_connection"
  end

  directory "/etc/pg2mysql/" do
    mode 0750
    owner "root"
    group "root"
  end

  # Remaining part of the loop should only be executed on the controller node with this role
  next unless node.roles.include? role

  db_override_conf = "/etc/pg2mysql/#{role}.mariadb-conf.d/"

  cmds = role_migration_data["db_sync_cmd"]
  cmds = [cmds] unless cmds.is_a?(Array)

  idx = 0
  cmds.each do |cmd|
    suffix = idx.zero? ? "" : "-#{idx}"
    log_file = "/var/log/crowbar/db-prepare.#{role}#{suffix}.log"
    log_redirect = "> #{log_file} 2>&1"
    commands << { cmd: ERB.new("#{cmd} #{log_redirect}").result(binding), role: role + suffix }
    idx += 1
  end

  directory db_override_conf do
    mode 0750
    owner "root"
    group "root"
  end

  template "#{db_override_conf}/999-db.conf" do
    source "mariadb-override.conf.erb"
    mode 0640
    owner "root"
    group "root"
    variables(
      db_conf_sections: db_conf_sections,
      db_connection_key: db_connection_key
    )
  end
end

include_recipe "database::client"
include_recipe "#{db_settings[:backend_name]}::client"
include_recipe "#{db_settings[:backend_name]}::python-client"

databases.each do |dbdata|
  db = dbdata[:db]
  # fill psql url for databases.yaml
  dbdata[:psql_url] = CrowbarOpenStackHelper.database_connection_string(psql_settings, db)
  Chef::Log.info("creating database #{db["database"]}")
  Chef::Log.info("creating database user #{db["user"]} with password #{db["password"]}")
  Chef::Log.info("db settings: #{db_settings.inspect}")

  database "create #{db[:database]} database (pg2my)" do
    connection db_settings[:connection]
    database_name db[:database]
    provider db_settings[:provider]
    action :create
  end

  database_user "create #{db[:user]} database user (pg2my)" do
    connection db_settings[:connection]
    username db[:user]
    password db[:password]
    host "%"
    provider db_settings[:user_provider]
    action :create
  end

  database_user "grant database access for #{db[:user]} database user (pg2my)" do
    connection db_settings[:connection]
    username db[:user]
    password db[:password]
    database_name db[:database]
    host "%"
    privileges db_settings[:privs]
    provider db_settings[:user_provider]
    require_ssl db_settings[:connection][:ssl][:enabled]
    action :grant
  end

end

commands.each do |command|
  execute "dbsync-role-#{command[:role]}" do
    command command[:cmd]
  end
end

# Write the index only on database node
template "/etc/pg2mysql/databases.yaml" do
  source "mariadb-databases.yaml.erb"
  mode 0640
  owner "root"
  group "root"
  variables(
    databases: databases
  )
  only_if { node.roles.include? "mysql-server" }
end
