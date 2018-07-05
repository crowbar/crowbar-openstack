name "neutron-sdn-cisco-aci-agents"
description "Nodes attached to one of the Cisco ACI Leaf Ports"

run_list("recipe[neutron::role_neutron_sdn_cisco_aci_agents]")
