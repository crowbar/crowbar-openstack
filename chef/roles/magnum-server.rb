name "magnum-server"
description "Magnum Role - Node registered as a Magnum server"
run_list("recipe[magnum::role_magnum_server]")
default_attributes
override_attributes
