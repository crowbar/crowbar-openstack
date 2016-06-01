name "horizon-server"
description "Horizon Server Role"
run_list("recipe[horizon::role_horizon_server]")
default_attributes
override_attributes
