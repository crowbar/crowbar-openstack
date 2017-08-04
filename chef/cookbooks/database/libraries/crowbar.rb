module CrowbarDatabaseHelper
  def self.get_ha_vhostname(node)
    if node[:database][:ha][:enabled]
      # Any change in the generation of the vhostname here must be reflected in
      # apply_role_pre_chef_call of the database barclamp model
      "#{node[:database][:config][:environment].gsub("-config", "")}-#{CrowbarPacemakerHelper.cluster_name(node)}".gsub("_", "-")
    else
      nil
    end
  end

  def self.get_listen_address(node)
    # FIXME: temporarily do not expect there's any VIP for mysql database
    if node[:database][:ha][:enabled] && node[:database][:sql_engine] != "mysql"
      vhostname = get_ha_vhostname(node)
      CrowbarPacemakerHelper.cluster_vip(node, "admin", vhostname)
    else
      Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    end
  end
end
