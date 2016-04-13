name "magnum-server"
description "Magnum Role - Node registered as a Magnum server"
run_list(
         "recipe[magnum]"
)
default_attributes()
override_attributes()

