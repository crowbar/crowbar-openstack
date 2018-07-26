name "database-server"
description "Database Server Role"
run_list("recipe[database::role_database_server]")
default_attributes()
override_attributes()

