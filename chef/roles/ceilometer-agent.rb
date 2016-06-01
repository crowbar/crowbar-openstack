name "ceilometer-agent"
description "Ceilometer Agent Role"
run_list("recipe[ceilometer::role_ceilometer_agent]")
default_attributes
override_attributes
