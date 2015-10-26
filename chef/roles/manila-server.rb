name "manila-server"
description "Manila API and Scheduler Role"
run_list("recipe[manila::role_manila_server]")
default_attributes
override_attributes
