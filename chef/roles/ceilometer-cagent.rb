name "ceilometer-cagent"
description "Ceilometer Central Agent Role"
run_list(
         "recipe[ceilometer::central]",
         "recipe[ceilometer::common]"
)
default_attributes()
override_attributes()

