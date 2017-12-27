name "neutron-midonet"
description "Neutron Midonet Nodes"

run_list("recipe[neutron::role_neutron_midonet]")
