name "ceilometer-server"
description "Ceilometer Server Role"
run_list("recipe[ceilometer::role_ceilometer_server]")
default_attributes
override_attributes
