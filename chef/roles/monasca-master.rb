name "monasca-master"
description "Monasca Ansible Master Role"
run_list("recipe[monasca::role_monasca_master]")
default_attributes
override_attributes
