name "octavia-backend"
description "Octavia Worker, health-manager and house-keeping"

run_list("recipe[octavia::role_octavia_backend]")
default_attributes
override_attributes
