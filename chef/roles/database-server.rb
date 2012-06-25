name "database-server"
description "Database Server Role"
run_list(
         "recipe[database::server]"
)
default_attributes()
override_attributes()

