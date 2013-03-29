name "ceilometer-server"
description "Ceilometer Server Role"
run_list(
         "recipe[ceilometer::server]",
         "recipe[ceilometer::common]"         
)
default_attributes()
override_attributes()

