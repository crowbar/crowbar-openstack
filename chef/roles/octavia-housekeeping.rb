name "octavia-housekeeping"
description "Octavia Housekeeping"

run_list("recipe[octavia::role_octavia_housekeeping]")
default_attributes
override_attributes
