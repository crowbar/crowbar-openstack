name "ceilometer-polling"
description "Ceilometer Polling Agent Role"
run_list(
         "recipe[ceilometer::polling]",
         "recipe[ceilometer::common]"
)
default_attributes()
override_attributes()
