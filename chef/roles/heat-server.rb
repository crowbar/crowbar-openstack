name "heat-server"
description "Heat Server Role"
run_list("recipe[heat::role_heat_server]")
default_attributes()
override_attributes()

