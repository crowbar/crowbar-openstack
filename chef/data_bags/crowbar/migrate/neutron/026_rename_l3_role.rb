def upgrade ta, td, a, d
  d["elements"]["neutron-network"] = d["elements"]["neutron-l3"]
  d["elements"].delete("neutron-l3")

  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # Make sure that all nodes that have the "neutron-l3" role
  # in their run_list are migrated to "neutron-network"
  nodes = NodeObject.find("roles:neutron-l3")
  nodes.each do |node|
    node.add_to_run_list("neutron-network",
                         td["element_run_list_order"]["neutron-network"],
                         td["element_states"]["neutron-network"])
    node.delete_from_run_list("neutron-l3")
    node.save
  end

  return a, d
end

def downgrade ta, td, a, d
  d["elements"]["neutron-l3"] = d["elements"]["neutron-network"]
  d["elements"].delete("neutron-network")

  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # Make sure that all nodes that have the "neutron-network" role
  # in their run_list are migrated to "neutron-l3"
  nodes = NodeObject.find("roles:neutron-network")
  nodes.each do |node|
    node.add_to_run_list("neutron-l3",
                         td["element_run_list_order"]["neutron-l3"],
                         td["element_states"]["neutron-l3"])
    node.delete_from_run_list("neutron-network")
    node.save
  end

  return a, d
end
