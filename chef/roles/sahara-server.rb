name "sahara-server"
description "sahara Role - Node registered as a sahara server"
run_list("recipe[sahara::role_sahara_server]")
default_attributes
override_attributes
