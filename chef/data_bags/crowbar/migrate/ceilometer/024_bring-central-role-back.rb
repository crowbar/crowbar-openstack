def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  # check if previous role is still installed (thus previous migration would run)
  original_role = "ceilometer-cagent"
  original_role = "ceilometer-polling" if File.exist? "/opt/dell/chef/roles/ceilometer-polling.rb"

  d["elements"]["ceilometer-central"] = d["elements"][original_role]
  d["elements"].delete(original_role)

  # Update the run_list for controller node
  nodes = NodeObject.find("run_list_map:#{original_role}")
  nodes.each do |node|
    node.add_to_run_list("ceilometer-central",
                         td["element_run_list_order"]["ceilometer-central"],
                         td["element_states"]["ceilometer-central"])
    node.delete_from_run_list(original_role)
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

  original_role = "ceilometer-cagent"
  original_role = "ceilometer-polling" if File.exist? "/opt/dell/chef/roles/ceilometer-polling.rb"

  # Update the run_list for controller node
  nodes = NodeObject.find("run_list_map:ceilometer-central")
  nodes.each do |node|
    node.add_to_run_list(original_role,
                         td["element_run_list_order"][original_role],
                         td["element_states"][original_role])
    node.delete_from_run_list("ceilometer-central")
    node.save
  end

  return a, d
end
