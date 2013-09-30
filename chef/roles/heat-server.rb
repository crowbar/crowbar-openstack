name "heat-server"
description "Heat Server Role"
run_list(
         "recipe[heat::server]",
         "recipe[heat::common]"
         
)
default_attributes()
override_attributes()

