name "octavia-server"
description "Octavia server"

run_list("recipe[octavia::role_octavia_server]")
