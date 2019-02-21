name "octavia-health-manager"
description "Octavia Health Manager"

run_list("recipe[octavia::role_octavia_health_manager]")
default_attributes
override_attributes
