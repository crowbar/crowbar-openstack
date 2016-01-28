name "nova-compute-ha"
description "Setup compute nodes HA for remote nodes, from a corosync node"
run_list(
  "recipe[nova::compute_ha]"
)
