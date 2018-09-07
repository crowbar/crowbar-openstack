databases = []
# The "barclamp" parameter doesn't really matter here, we want to use the same
# instance for all databases.
db_settings = CrowbarOpenStackHelper.database_settings(node, "mysql")
CrowbarDatabaseHelper.roles_using_database.each do |role|
  next unless node.roles.include? role

  role_migration_data = CrowbarDatabaseHelper.role_migration_data(role)
  barclamp = role_migration_data["barclamp"]

  db = if role == "ec2-api"
    node[barclamp]["ec2-api"]["db"]
  else
    node[barclamp]["db"]
  end
  databases << db
  db_conf_sections = {}
  db_connection_key = "connection"
  connection = CrowbarOpenStackHelper.database_connection_string(db_settings, db)
  Chef::Log.info("connection string: #{connection}")
  db_conf_sections["database"] = connection

  # The nova-controller role creates more than one database
  if role == "nova-controller"
    databases << node[barclamp]["api_db"]
    connection = CrowbarOpenStackHelper.database_connection_string(db_settings,
      node[barclamp]["api_db"])
    Chef::Log.info("connection string: #{connection}")
    db_conf_sections["api_database"] = connection
    databases << node[barclamp]["placement_db"]
    connection = CrowbarOpenStackHelper.database_connection_string(db_settings,
      node[barclamp]["placement_db"])
    Chef::Log.info("connection string: #{connection}")
    db_conf_sections["placement_database"] = connection
  end
  # Barbican uses non-standard db config structure
  if role == "barbican-controller"
    db_conf_sections = { "DEFAULT" => connection }
    db_connection_key = "sql_connection"
  end

  db_override_conf = "/etc/pg2mysql/#{role}.mariadb-conf.d/"
  directory "/etc/pg2mysql/" do
    mode 0750
    owner "root"
    group "root"
  end

  directory "/etc/pg2mysql/scripts" do
    mode 0750
    owner "root"
    group "root"
  end

  cmds = role_migration_data["db_sync_cmd"]
  cmds = [cmds] unless cmds.is_a?(Array)

  template "/etc/pg2mysql/scripts/#{role}-db_sync.sh" do
    source "mariadb-db_sync.sh.erb"
    mode 0750
    owner "root"
    group "root"
    variables(
      db_sync_cmds: cmds,
      db_conf_sections: db_conf_sections,
      db_override_conf: db_override_conf
    )
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

databases.each do |db|
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
