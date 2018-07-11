name "designate-designate-worker"
description "designate Role - Node registered as a designate worker"
run_list("recipe[designate::role_designate_worker]")
default_attributes
override_attributes
