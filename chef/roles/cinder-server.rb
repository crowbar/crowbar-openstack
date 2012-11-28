name "cinder-server"
description "Cinder Server Role"
run_list(
         "recipe[cinder::api]",
         "recipe[cinder::scheduler]",
         "recipe[cinder::volume]",
         "recipe[cinder::monitor]"
)
default_attributes()
override_attributes()

