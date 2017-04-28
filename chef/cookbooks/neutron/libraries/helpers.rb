module NeutronHelper
  def self.get_bind_host_port(node)
    if node[:neutron][:ha][:server][:enabled]
      admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      bind_host = admin_address
      bind_port = node[:neutron][:ha][:ports][:server]
    else
      bind_host = node[:neutron][:api][:service_host]
      bind_port = node[:neutron][:api][:service_port]
    end
    return bind_host, bind_port
  end

  # Find out how many (and which) physnets we need to define in neutron.
  # Input is the list of external_networks that we'll have. Returns a hash where
  # external_network -> physnet pairs
  def self.get_neutron_physnets(node, external_networks)
    # This assumes that "nova_fixed" will always be on the phynet called
    # "physnet1" in neutron
    # Also we don't allow to put 2 external networks on the same neutron
    # physnet.

    networks = Hash.new
    interfaces_used = Hash.new
    external_networks.each do |net|
      networks[net] = BarclampLibrary::Barclamp::Inventory.get_network_by_type(node, net)

      if interfaces_used[networks[net].interface]
        Chef::Log.error(
          "Networks '#{net}' and '#{interfaces_used[networks[net].interface]}' " \
          "will use the same physical interface (#{networks[net].interface}) " \
          "on node #{node.name}.")
        raise "Two or more external networks will end up on the same physical interface."
      else
        interfaces_used[networks[net].interface] = net
      end
    end

    # Now check if any of the external network will share the physical interface
    # with "nova_fixed" if the node has "nova_fixed" enabled.
    fixed_interface = ""
    fixed_physnet = ""
    if node[:crowbar_wall][:network][:nets][:nova_fixed]
      nova_fixed_net = BarclampLibrary::Barclamp::Inventory.get_network_by_type(node, "nova_fixed")
      fixed_interface = nova_fixed_net.interface
      fixed_physnet = "physnet1"
    end

    physmap = Hash.new
    networks.each do |net, net_object|
      physmap[net] = if net_object.interface == fixed_interface
        fixed_physnet
      elsif net == "nova_floating"
        "floating"
      else
        net
      end
    end
    physmap
  end

  # Returns the node object referring the first network-node
  def self.get_network_node_from_neutron_attributes(node)
    if node.roles.include?("neutron-network")
      return node
    else
      network_node_name = ""
      if node[:neutron][:ha][:network][:enabled]
        # network role is deployed in an HA mode, pick the first node
        network_node_name = node[:neutron][:elements_expanded][:'neutron-network'][0]
      else
        network_node_name = node[:neutron][:elements][:'neutron-network'][0]
      end
      Chef::Node.load(network_node_name)
    end
  end
end
