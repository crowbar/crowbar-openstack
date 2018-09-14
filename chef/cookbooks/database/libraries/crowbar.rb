module CrowbarDatabaseHelper
  def self.get_ha_vhostname(node, sql_engine = node[:database][:sql_engine])
    if node["database"][sql_engine]["ha"]["enabled"]
      cluster_name = CrowbarPacemakerHelper.cluster_name(node)
      # Any change in the generation of the vhostname here must be reflected in
      # apply_role_pre_chef_call of the database barclamp model
      if sql_engine == "postgresql"
        "#{node[:database][:config][:environment].gsub("-config", "")}-#{cluster_name}".tr("_", "-")
      else
        "cluster-#{cluster_name}".tr("_", "-")
      end
    else
      nil
    end
  end

  def self.get_listen_address(node, sql_engine = node[:database][:sql_engine])
    # For SSL we prefer a cluster hostname (for certificate validation)
    use_ssl = sql_engine == "mysql" && node[:database][:mysql][:ssl][:enabled]
    if node["database"][sql_engine]["ha"]["enabled"]
      vhostname = get_ha_vhostname(node, sql_engine)
      use_ssl ? "#{vhostname}.#{node[:domain]}" : CrowbarPacemakerHelper.cluster_vip(node, "admin", vhostname)
    else
      use_ssl ? node[:fqdn] : Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    end
  end

  def self.roles_using_database
    migration_data.keys
  end

  def self.role_migration_data(role)
    migration_data[role]
  end

  def self.migration_data
    {
      "keystone-server" => {
        "barclamp" => "keystone",
        "db_sync_cmd" => "keystone-manage --config-dir /etc/keystone/keystone.conf.d/ " \
          "--config-dir <%=@db_override_conf%> db_sync"
      },
      "glance-server" => {
        "barclamp" => "glance",
        "db_sync_cmd" => "glance-manage --config-dir /etc/glance/glance.conf.d/ " \
          "--config-dir <%=@db_override_conf%> db_sync"
      },
      "cinder-controller" => {
        "barclamp" => "cinder",
        "db_sync_cmd" => "cinder-manage --config-dir /etc/cinder/cinder.conf.d/ " \
          "--config-dir <%=@db_override_conf%> db sync"
      },
      "manila-server" => {
        "barclamp" => "manila",
        "db_sync_cmd" => "manila-manage --config-dir /etc/manila/manila.conf.d/ " \
          "--config-dir <%=@db_override_conf%> db sync"
      },
      "neutron-server" => {
        "barclamp" => "neutron",
        "db_sync_cmd" => "neutron-db-manage --config-dir /etc/neutron/neutron.conf.d/ " \
          "--config-dir <%=@db_override_conf%> upgrade head"
      },
      "nova-controller" => {
        "barclamp" => "nova",
        "db_sync_cmd" => [
          "nova-manage --config-dir /etc/nova/nova.conf.d/ " \
            "--config-dir <%=@db_override_conf%> api_db sync",
          "nova-manage --config-dir /etc/nova/nova.conf.d/ " \
            "--config-dir <%=@db_override_conf%> db sync"
        ]
      },
      # ec2 is special in that it's attributes are part of the nova barclamp
      "ec2-api" => {
        "barclamp" => "nova",
        "db_sync_cmd" => "ec2-api-manage --config-dir /etc/ec2api/ec2api.conf.d/ " \
          "--config-dir <%=@db_override_conf%> db_sync"
      },
      # django migration tool uses db settings from
      # /srv/www/openstack-dashboard/openstack_dashboard/local/local.settings.d/_100_local_settings.py
      "horizon-server" => {
        "barclamp" => "horizon",
        "db_sync_cmd" => "python /srv/www/openstack-dashboard/manage.py migrate --database mysql"
      },
      "ceilometer-server" => {
        "barclamp" => "ceilometer",
        "db_sync_cmd" => "ceilometer-dbsync --config-dir /etc/ceilometer/ceilometer.conf.d/ " \
          "--config-dir <%=@db_override_conf%>"
      },
      "heat-server" => {
        "barclamp" => "heat",
        "db_sync_cmd" => "heat-manage --config-dir /etc/heat/heat.conf.d/ " \
                         "--config-dir <%=@db_override_conf%> db_sync"
      },
      "aodh-server" => {
        "barclamp" => "aodh",
        "db_sync_cmd" => "aodh-dbsync --config-dir /etc/aodh/aodh.conf.d/ " \
          "--config-dir <%=@db_override_conf%>"
      },
      "barbican-controller" => {
        "barclamp" => "barbican",
        # this doesn't work because of a bug in barbican-manage handling of oslo_config
        # "db_sync_cmd" => "barbican-manage --config-dir /etc/barbican/barbican.conf.d/ " \
        #   "--config-dir <%=@db_override_conf%> db upgrade"
        "db_sync_cmd" => "barbican-manage db upgrade --db-url <%=@db_conf_sections['DEFAULT']%>"
      },
      "magnum-server" => {
        "barclamp" => "magnum",
        "db_sync_cmd" => "magnum-db-manage --config-dir /etc/magnum/magnum.conf.d/ " \
          "--config-dir <%=@db_override_conf%> upgrade"
      },
      "sahara-server" => {
        "barclamp" => "sahara",
        "db_sync_cmd" => "sahara-db-manage --config-dir /etc/sahara/sahara.conf.d/ " \
          "--config-dir <%=@db_override_conf%> upgrade head"
      },
      "trove-server" => {
        "barclamp" => "trove",
        "db_sync_cmd" => "trove-manage --config-dir /etc/trove/trove.conf.d/ " \
          "--config-dir <%=@db_override_conf%> db_sync"
      }
    }
  end

  private_class_method :migration_data
end
