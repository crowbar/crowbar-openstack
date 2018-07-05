# frozen_string_literal: true

def upgrade(ta, td, a, d)
  unless d["element_states"].key?("neutron-sdn-cisco-aci-agents")
    d["element_states"] = td["element_states"]
    d["element_order"] = td["element_order"]
    d["element_run_list_order"] = td["element_run_list_order"]

    if a["networking_plugin"] == "ml2" &&
        (a["ml2_mechanism_drivers"].include?("cisco_apic_ml2") ||
        a["ml2_mechanism_drivers"].include?("apic_gbp"))
      nodes = NodeObject.find("roles:nova-compute-kvm")
      nodes.each do |node|
        node.add_to_run_list("neutron-sdn-cisco-aci-agents",
                             td["element_run_list_order"]["neutron-sdn-cisco-aci-agents"],
                             td["element_states"]["neutron-sdn-cisco-aci-agents"])
        node.save
      end
    end
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless td["element_states"].key?("neutron-sdn-cisco-aci-agents")
    d["element_states"] = td["element_states"]
    d["element_order"] = td["element_order"]
    d["element_run_list_order"] = td["element_run_list_order"]
    d["elements"].delete("neutron-sdn-cisco-aci-agents")

    nodes = NodeObject.find("roles:neutron-sdn-cisco-aci-agents")
    nodes.each do |node|
      node.delete_from_run_list("neutron-sdn-cisco-aci-agents")
      node.save
    end
  end

  return a, d
end
