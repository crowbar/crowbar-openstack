name "cinder-controller"
description "Cinder API and Scheduler Role"
run_list(
  "recipe[cinder::api]",
  "recipe[cinder::scheduler]",
  "recipe[cinder::monitor]"
)
default_attributes()
override_attributes()
