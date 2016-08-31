def upgrade(ta, td, a, d)
  d["elements"].delete("barbican-server")
  d["elements"].delete("barbican-retry")
  d["elements"].delete("barbican-worker")
  d["elements"].delete("barbican-keystone_listener")
  d["elements"].add("barbican-controller")

  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  roles = ["barbican-server", "barbican-retry", "barbican-worker", "barbican-keystone_listener"]
  roles.each do |role|
    nodes = NodeObject.find("roles:#{role}")
    nodes.each do |node|
      node.add_to_run_list("barbican-controller",
                           td["element_run_list_order"][@role],
                           td["element_states"][@role])
      node.delete_from_run_list(@role)
      node.save
    end
  end

  return a, d
end

def downgrade(ta, td, a, d)
  d["elements"].add("barbican-server")
  d["elements"].add("barbican-retry")
  d["elements"].add("barbican-worker")
  d["elements"].add("barbican-keystone_listener")
  d["elements"].delete("barbican-controller")

  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  roles = ["barbican-server", "barbican-retry", "barbican-worker", "barbican-keystone_listener"]
  nodes = NodeObject.find("roles:barbican-controller")
  nodes.each do |node|
    roles.each do |role|
      node.add_to_run_list(@role,
                           td["element_run_list_order"][@role],
                           td["element_states"][@role])
      node.delete_from_run_list("barbican-controller")
      node.save
    end
  end

  return a, d
end
