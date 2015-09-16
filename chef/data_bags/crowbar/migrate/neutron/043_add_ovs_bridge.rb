def upgrade(ta, td, a, d)
  ns = NeutronService.new Rails.logger
  nodes = NodeObject.find("roles:neutron-network")
  nodes << NodeObject.find("roles:nova-multi-compute-* NOT roles:nova-multi-compute-vmware")
  nodes.flatten!
  nodes.each do |node|
    ns.update_ovs_bridge_attributes(a, node)
  end
  return a, d
end
