name "neutron-server"
description "Neutron server"

run_list(
  "recipe[neutron::server]",
  "recipe[neutron::monitor]"
)
