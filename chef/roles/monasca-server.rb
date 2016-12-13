name "monasca-server"
description "Monasca Server Role"
run_list("recipe[monasca::role_monasca_server]")
default_attributes
override_attributes
