name "cinder-controller"
description "Cinder API and Scheduler Role"
run_list("recipe[cinder::role_cinder_controller]")
default_attributes()
override_attributes()
