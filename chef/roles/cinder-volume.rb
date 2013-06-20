name "cinder-volume"
description "Cinder volume Role"
run_list(
  "recipe[cinder::volume]"
)
default_attributes()
override_attributes()
