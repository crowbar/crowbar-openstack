name "oscm-server"
description "OSCM Server Role"
run_list("recipe[oscm::role_oscm_server]")
default_attributes
override_attributes