name "octavia-certificates-sharing"
description "Octavia certificates sharing"

run_list("recipe[octavia::role_octavia_certificates_sharing]")
default_attributes
override_attributes
