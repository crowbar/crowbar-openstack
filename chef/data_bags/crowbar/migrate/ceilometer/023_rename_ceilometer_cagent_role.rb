def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # Change the elements to ceilometer-polling
  d["elements"]["ceilometer-polling"] = d["elements"]["ceilometer-cagent"]
  d["elements"].delete("ceilometer-cagent")

  # Update the run_list for controller node
  node = NodeObject.find("roles:ceilometer-cagent").first
  if node
    node.add_to_run_list("ceilometer-polling",
                         td["element_run_list_order"]["ceilometer-polling"],
                         td["element_states"]["ceilometer-polling"])
    node.delete_from_run_list("ceilometer-cagent")
    node.save
  end

  return a, d
end

def downgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # Change the elements to ceilometer-polling
  d["elements"]["ceilometer-cagent"] = d["elements"]["ceilometer-polling"]
  d["elements"].delete("ceilometer-polling")

  # Update the run_list for controller node
  node = NodeObject.find("roles:ceilometer-polling").first
  if node
    node.add_to_run_list("ceilometer-cagent",
                         td["element_run_list_order"]["ceilometer-cagent"],
                         td["element_states"]["ceilometer-cagent"])
    node.delete_from_run_list("ceilometer-polling")
    node.save
  end

  return a, d
end
