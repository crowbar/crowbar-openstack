name "neutron-network"
description "Neutron Network Agents"

run_list("recipe[neutron::role_neutron_network]")
