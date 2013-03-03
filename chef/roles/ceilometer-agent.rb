name "ceilometer-agent"
description "Ceilometer Agent Role"
run_list(
         "recipe[ceilometer::agent]"
)
default_attributes()
override_attributes()

