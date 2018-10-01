def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  if d["elements"]["ec2-api"]
    d["elements"].delete("ec2-api")
  end
  if d.fetch("elements_expanded", {}).key? "ec2-api"
    d["elements_expanded"].delete("ec2-api")
  end

  nodes = NodeObject.find("run_list_map:ec2-api")
  nodes.each do |node|
    node.delete_from_run_list("ec2-api")
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
