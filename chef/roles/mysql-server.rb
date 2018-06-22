name "mysql-server"
description "MySQL/MariaDB Server Role"
run_list("recipe[database::role_mysql_server]")
default_attributes()
override_attributes()
