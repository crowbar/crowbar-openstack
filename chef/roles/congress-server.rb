name "congress-server"
description "Congress Role - Node registered as a Congress server"
run_list(
         "recipe[congress::api]",
         "recipe[congress::common]",
         "recipe[congress::controller_ha]"
)
default_attributes()
override_attributes()

