name "nova-compute-docker"
description "Installs requirements to run a Compute node in a Nova cluster"
run_list("recipe[nova::role_nova_compute_docker]")
