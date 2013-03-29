name "ceilometer-agent"
description "Ceilometer Agent Role"
run_list(
         "recipe[ceilometer::agent]",
         "recipe[ceilometer::common]"
)
default_attributes()
override_attributes()

