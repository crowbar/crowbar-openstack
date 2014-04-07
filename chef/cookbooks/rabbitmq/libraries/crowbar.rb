module CrowbarRabbitmqHelper
  def self.get_ha_vhostname(node)
    if node[:rabbitmq][:ha][:enabled]
      "#{node[:rabbitmq][:config][:environment].gsub("-config", "")}-#{CrowbarPacemakerHelper.cluster_name(node)}".gsub("_", "-")
    else
      nil
    end
  end

  def self.get_listen_address(node)
    if node[:rabbitmq][:ha][:enabled]
      vhostname = get_ha_vhostname(node)
      net_db = Chef::DataBagItem.load('crowbar', 'admin_network').raw_data
      net_db["allocated_by_name"]["#{vhostname}.#{node[:domain]}"]["address"]
    else
      Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    end
  end
end
