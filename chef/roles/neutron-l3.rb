name "neutron-l3"
description "Neutron L3"

run_list(
  "recipe[neutron::l3]"
)
