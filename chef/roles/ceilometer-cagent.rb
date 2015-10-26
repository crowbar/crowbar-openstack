name "ceilometer-cagent"
description "Ceilometer Central Agent Role"
run_list("recipe[ceilometer::role_ceilometer_cagent]")
default_attributes()
override_attributes()
