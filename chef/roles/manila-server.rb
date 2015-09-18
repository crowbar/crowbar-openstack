name "manila-server"
description "Manila API and Scheduler Role"
run_list(
  "recipe[manila::api]",
  "recipe[manila::scheduler]",
  "recipe[manila::controller_ha]"
)
default_attributes
override_attributes
