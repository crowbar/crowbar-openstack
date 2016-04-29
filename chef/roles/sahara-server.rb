name "sahara-server"
description "sahara Role - Node registered as a sahara server"
run_list(
  "recipe[sahara::setup]",
  "recipe[sahara::common]",
  "recipe[sahara::sql]",
  "recipe[sahara::api]",
  "recipe[sahara::conductor]"
)
default_attributes
override_attributes
