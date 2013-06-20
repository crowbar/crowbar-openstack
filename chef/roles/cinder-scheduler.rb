name "cinder-scheduler"
description "Cinder scheduler Role"
run_list(
  "recipe[cinder::scheduler]"
)
default_attributes()
override_attributes()
