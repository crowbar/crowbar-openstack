name "trove-server"
description "Trove Role - Node registered as a Trove server"
run_list(
         "recipe[trove]"
)
default_attributes()
override_attributes()

