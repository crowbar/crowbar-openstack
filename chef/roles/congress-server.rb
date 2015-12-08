name "congress-server"
description "Congress Role - Node registered as a Congress server"
run_list(
         "recipe[congress]"
)
default_attributes()
override_attributes()

