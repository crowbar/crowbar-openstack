name "neutron-server"
description "Neutron server"

run_list("recipe[neutron::role_neutron_server]")
