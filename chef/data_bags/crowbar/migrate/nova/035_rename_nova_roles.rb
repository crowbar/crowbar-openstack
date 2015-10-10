def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  %w(controller compute-docker compute-hyperv compute-kvm compute-qemu compute-vmware compute-xen compute-zvm).each do |role|
    d["elements"]["nova-#{role}"] = d["elements"]["nova-multi-#{role}"]
    d["elements"].delete("nova-multi-#{role}")

    # Make sure that all nodes that have the multi role
    # in their run_list are migrated to new name
    nodes = NodeObject.find("roles:nova-multi-#{role}")
    nodes.each do |node|
      node.add_to_run_list("nova-#{role}",
                           td["element_run_list_order"]["nova-#{role}"],
                           td["element_states"]["nova-#{role}"])
      node.delete_from_run_list("nova-multi-#{role}")
      node.save
    end
  end

  return a, d
end

def downgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  %w(controller compute-docker compute-hyperv compute-kvm compute-qemu compute-vmware compute-xen compute-zvm).each do |role|
    d["elements"]["nova-multi-#{role}"] = d["elements"]["nova-#{role}"]
    d["elements"].delete("nova-#{role}")

    # Make sure that all nodes that have the multi role
    # in their run_list are migrated to new name
    nodes = NodeObject.find("roles:nova-#{role}")
    nodes.each do |node|
      node.add_to_run_list("nova-multi-#{role}",
                           td["element_run_list_order"]["nova-multi-#{role}"],
                           td["element_states"]["nova-multi-#{role}"])
      node.delete_from_run_list("nova-#{role}")
      node.save
    end
  end

  return a, d
end
