# FIXME this is still missing a couple of openstack barclamps
roles_using_database = {
  "keystone-server" => {
    "barclamp" => "keystone",
    "db_sync_cmd" => "keystone-manage --config-dir /etc/keystone/keystone.conf.d/ --config-dir %{db_override_conf} db_sync"
  },
  "glance-server" => {
    "barclamp" => "glance",
    "db_sync_cmd" => "glance-manage --config-dir /etc/glance/glance.conf.d/ --config-dir %{db_override_conf} db_sync"
  },
  "cinder-controller" => {
    "barclamp" => "cinder",
    "db_sync_cmd" => "cinder-manage --config-dir /etc/cinder/cinder.conf.d/ --config-dir %{db_override_conf} db sync"
  },
  "manila-server" => {
    "barclamp" => "manila",
    "db_sync_cmd" => "manila-manage --config-dir /etc/manila/manila.conf.d/ --config-dir %{db_override_conf} db sync"
  },
  "neutron-server" => {
    "barclamp" => "neutron",
    "db_sync_cmd" => "neutron-db-manage --config-dir /etc/neutron/neutron.conf.d/ --config-dir %{db_override_conf} upgrade head"
  },
  "nova-controller" => {
    "barclamp" => "nova",
    "db_sync_cmd" => [
      "nova-manage --config-dir /etc/nova/nova.conf.d/ --config-dir %{db_override_conf} db sync",
      "nova-manage --config-dir /etc/nova/nova.conf.d/ --config-dir %{db_override_conf} api_db sync"
    ]
  },
  # ec2 is special in that it's attributes are part of the nova barclamp
  "ec2-api" => {
    "barclamp" => "nova",
    "ec2-api-manage --config-dir /etc/ec2api/ec2api.conf.d/ --config-dir %{db_override_conf} db_sync",
  },
  "horizon-server" => {
    "barclamp" => "horizon",
    "db_sync_cmd" => "--config-file %{db_override_conf}"
  },
  "ceilometer-server" => {
    "barclamp" => "ceilometer",
    "db_sync_cmd" => "--config-file %{db_override_conf}"
  },
  "heat-server" => {
    "barclamp" => "heat",
    "db_sync_cmd" => "--config-file %{db_override_conf}"
  },
  "aodh-server" => {
    "barclamp" => "aodh",
    "db_sync_cmd" => "--config-file %{db_override_conf}"
  }
}

databases = []
# The "barclamp" parameter doesn't really matter here, we want to use the same
# instance for all databases. And we specify that instance my name (currently
# hard-coded to "maria"
db_settings = CrowbarOpenStackHelper.database_settings(node, "keystone", "maria")
roles_using_database.keys.each do |role|
  if node.roles.include? role
    barclamp = roles_using_database[role]["barclamp"]

    db = if role == "ec2-api"
           node[barclamp]["ec2-api"]["db"]
         else
           node[barclamp]["db"]
         end
    databases << db
    db_conf_sections = {}
    connection = CrowbarOpenStackHelper.database_connection_string(db_settings, db )
    Chef::Log.info("connection string: #{connection}")
    db_conf_sections["database"] = connection

    # The nova-controller role creates more than one database
    if role == "nova-controller"
      databases << node[barclamp]["api_db"]
      connection = CrowbarOpenStackHelper.database_connection_string(db_settings, node[barclamp]["api_db"] )
      Chef::Log.info("connection string: #{connection}")
      db_conf_sections["api_database"] = connection
      databases << node[barclamp]["placement_db"]
      connection = CrowbarOpenStackHelper.database_connection_string(db_settings, node[barclamp]["placement_db"] )
      Chef::Log.info("connection string: #{connection}")
      db_conf_sections["placement_database"] = connection
    end

    db_override_conf = "/etc/pg2mysql/#{role}.mariadb-conf.d/"
    directory "/etc/pg2mysql/" do
      mode 0750
      owner "root"
      group "root"
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
        db_conf_sections: db_conf_sections
      )
    end
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
#    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  database_user "create #{db[:user]} database user (pg2my)" do
    connection db_settings[:connection]
    username db[:user]
    password db[:password]
    host "%"
    provider db_settings[:user_provider]
    action :create
#    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
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
#    only_if { !ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

end
