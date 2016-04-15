name "magnum-server"
description "Magnum Role - Node registered as a Magnum server"
run_list(
  "recipe[magnum::setup]",
  "recipe[magnum::common]",
  "recipe[magnum::sql]",
  "recipe[magnum::api]",
  "recipe[magnum::conductor]"
)
default_attributes
override_attributes
