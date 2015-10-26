name "tempest"
description "Tempest Role - does tempest installation"
run_list("recipe[tempest::role_tempest]")
default_attributes()
override_attributes()
