module CrowbarRabbitmqHelper
  def self.get_ha_vhostname(node)
    if node[:rabbitmq][:ha][:enabled]
      "#{node[:rabbitmq][:config][:environment].gsub("-config", "")}-#{CrowbarPacemakerHelper.cluster_name(node)}".gsub("_", "-")
    else
      nil
    end
  end

  def self.get_listen_address(node)
    if node[:rabbitmq][:ha][:enabled] && !node[:rabbitmq][:cluster]
      vhostname = get_ha_vhostname(node)
      CrowbarPacemakerHelper.cluster_vip(node, "admin", vhostname)
    else
      Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
    end
  end

  def self.get_public_listen_address(node)
    if node[:rabbitmq][:ha][:enabled] && !node[:rabbitmq][:cluster]
      vhostname = get_ha_vhostname(node)
      CrowbarPacemakerHelper.cluster_vip(node, "public", vhostname)
    else
      Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
    end
  end

  def self.get_management_address(node)
    get_listen_address(node)
  end

  def self.ha_policy_regex
    # don't mirror queues that are 'amq.*' or '*_fanout_*' or `reply_*` in their names
    "^(?!(amq.)|(.*_fanout_)|(reply_)).*"
  end

  def self.get_ha_policy_definition(node)
    quorum = 1
    if node[:rabbitmq][:enable_queue_mirroring] && node[:rabbitmq][:ha][:enabled]
      quorum = CrowbarPacemakerHelper.num_corosync_nodes(node) / 2 + 1
    end

    {
      "ha-mode"      => "exactly",
      "ha-params"    => quorum,
      "ha-sync-mode" => "automatic"
    }
  end
end
