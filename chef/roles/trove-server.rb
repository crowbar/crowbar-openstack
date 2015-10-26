name "trove-server"
description "Trove Role - Node registered as a Trove server"
run_list("recipe[trove::role_trove_server]")
default_attributes()
override_attributes()

