name "octavia-api"
description "Octavia API"

run_list("recipe[octavia::role_octavia_api]")
default_attributes
override_attributes
