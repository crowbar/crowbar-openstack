name "ceilometer-server"
description "Ceilometer Server Role"
run_list(
         "recipe[ceilometer::server]"
)
default_attributes()
override_attributes()

