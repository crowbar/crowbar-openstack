name "octavia-worker"
description "Octavia Worker"

run_list("recipe[octavia::role_octavia_worker]")
default_attributes
override_attributes
