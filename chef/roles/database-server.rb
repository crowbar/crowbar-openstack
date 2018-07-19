name "database-server"
description "PostgreSQL Server Role"
run_list("recipe[database::role_database_server]")
default_attributes()
override_attributes()
