name "horizon-server"
description "Horizon Server Role"
run_list(
 "recipe[horizon::server]",
 "recipe[horizon::monitor]"
)
default_attributes
override_attributes
