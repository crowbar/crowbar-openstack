name "oat-server"
description "Oat Server Role"
run_list(
         "recipe[oat::install_server]"
)
default_attributes()
override_attributes()

