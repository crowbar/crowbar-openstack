name "barbican-keystone-listener"
description "Barbican keystone-listener Role"
run_list(
  "recipe[barbican::role_barbican_keystone_listener]",
)
default_attributes
override_attributes
