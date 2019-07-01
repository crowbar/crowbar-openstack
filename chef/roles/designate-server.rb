name "designate-server"
description "designate Role - Node registered as a designate server"
run_list("recipe[designate::role_designate_server]")
default_attributes
override_attributes
