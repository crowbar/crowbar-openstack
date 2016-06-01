name "ceilometer-central"
description "Ceilometer Central Agent Role"
run_list("recipe[ceilometer::role_ceilometer_central]")
default_attributes
override_attributes
