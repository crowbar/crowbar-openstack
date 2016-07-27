name "barbican-worker"
description "Barbican worker Role"
run_list(
  "recipe[barbican::role_barbican_worker]",
)
default_attributes
override_attributes
