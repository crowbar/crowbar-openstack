def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  if d["elements"]["nova-compute-hyperv"]
    d["elements"].delete("nova-compute-hyperv")
  end
  if d.fetch("elements_expanded", {}).key? "nova-compute-hyperv"
    d["elements_expanded"].delete("nova-compute-hyperv")
  end

  nodes = NodeObject.find("run_list_map:nova-compute-hyperv")
  nodes.each do |node|
    node.delete_from_run_list("nova-compute-hyperv")
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
