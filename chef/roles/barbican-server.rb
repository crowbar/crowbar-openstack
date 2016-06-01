name "barbican-server"
description "Barbican Role"
run_list(
  "recipe[barbican::role_barbican_server]",
)
default_attributes
override_attributes
