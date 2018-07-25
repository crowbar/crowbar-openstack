module CrowbarDatabaseHelper
  def self.get_ha_vhostname(node, sql_engine=node[:database][:sql_engine])
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

  def self.get_listen_address(node, sql_engine=node[:database][:sql_engine])
    # For SSL we prefer a cluster hostname (for certificate validation)
    use_ssl = sql_engine == "mysql" && node[:database][:mysql][:ssl][:enabled]
    if node["database"][sql_engine]["ha"]["enabled"]
      vhostname = get_ha_vhostname(node)
      use_ssl ? "#{vhostname}.#{node[:domain]}" : CrowbarPacemakerHelper.cluster_vip(node, "admin", vhostname)
    else
      use_ssl ? node[:fqdn] : Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    end
  end
end
