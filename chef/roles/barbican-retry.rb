name "barbican-retry"
description "Barbican retry Role"
run_list(
  "recipe[barbican::role_barbican_retry]",
)
default_attributes
override_attributes
