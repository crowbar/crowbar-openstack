def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # Remove agent role from compute nodes
  nodes = NodeObject.find("run_list_map:ceilometer-agent")
  nodes.each do |node|
    node.delete_from_run_list("ceilometer-agent")
    node.save
  end
  return a, d
end

def downgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]
  return a, d
end
