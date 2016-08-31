name "barbican-controller"
description "Barbican Controller Role"
run_list("recipe[barbican::role_barbican_controller]")
default_attributes
override_attributes
