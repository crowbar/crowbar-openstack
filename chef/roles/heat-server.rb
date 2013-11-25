name "heat-server"
description "Heat Server Role"
run_list(
         "recipe[heat::server]",
         "recipe[heat::common]",
         "recipe[heat::monitor]"
)
default_attributes()
override_attributes()

