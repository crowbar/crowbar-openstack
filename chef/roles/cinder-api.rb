name "cinder-api"
description "Cinder API Role"
run_list(
  "recipe[cinder::api]",
  "recipe[cinder::monitor]"
)
default_attributes()
override_attributes()
