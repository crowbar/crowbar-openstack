def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # ceilometer-central might be already present if the setup is an upgrade from Cloud6
  unless d["elements"].key? "ceilometer-central"
    d["elements"]["ceilometer-central"] = d["elements"]["ceilometer-polling"]
    d["elements"].delete("ceilometer-polling")
  end

  # Update the run_list for controller node
  nodes = NodeObject.find("run_list_map:ceilometer-polling")
  nodes.each do |node|
    node.add_to_run_list("ceilometer-central",
                         td["element_run_list_order"]["ceilometer-central"],
                         td["element_states"]["ceilometer-central"])
    node.delete_from_run_list("ceilometer-polling")
    node.save
  end

  return a, d
end

def downgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  d["elements"]["ceilometer-polling"] = d["elements"]["ceilometer-central"]
  d["elements"].delete("ceilometer-central")

  # Update the run_list for controller node
  nodes = NodeObject.find("run_list_map:ceilometer-central")
  nodes.each do |node|
    node.add_to_run_list("ceilometer-polling",
                         td["element_run_list_order"]["ceilometer-polling"],
                         td["element_states"]["ceilometer-polling"])
    node.delete_from_run_list("ceilometer-central")
    node.save
  end

  return a, d
end
