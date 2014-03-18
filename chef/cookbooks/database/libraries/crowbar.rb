module CrowbarDatabaseHelper
  def self.get_listen_address(node)
    Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  end
end
