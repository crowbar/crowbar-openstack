name "monasca-agent"
description "Monasca Agent Role"
run_list("recipe[monasca::role_monasca_agent]")
default_attributes
override_attributes
