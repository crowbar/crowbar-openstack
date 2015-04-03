name "neutron-network"
description "Neutron Network Agents"

run_list(
  "recipe[neutron::network_agents]"
)
