# frozen_string_literal: true

def upgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  nodes = NodeObject.find("roles:nova-compute-kvm")
  nodes.each do |node|
    next unless node["neutron"]["networking_plugin"] == "ml2" &&
        (node["neutron"]["mechanism_drivers"].include?("cisco_apic_ml2") ||
        node["neutron"]["mechanism_drivers"].include?("apic_gbp"))
    node.add_to_run_list("neutron-sdn-cisco-aci-agents",
                         td["element_run_list_order"]["neutron-sdn-cisco-aci-agents"],
                         td["element_states"]["neutron-sdn-cisco-aci-agents"])
    node.save
  end

  return a, d
end

def downgrade(ta, td, a, d)
  d["element_states"] = td["element_states"]
  d["element_order"] = td["element_order"]
  d["element_run_list_order"] = td["element_run_list_order"]

  nodes = NodeObject.find("roles:neutron-sdn-cisco-aci-agents")
  nodes.each do |node|
    node.delete_from_run_list("neutron-sdn-cisco-aci-agents")
    node.save
  end

  return a, d
end
