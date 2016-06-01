name "ceilometer-agent-hyperv"
description "Ceilometer Agent Role on HyperV Hosts"
run_list("recipe[ceilometer::role_ceilometer_agent_hyperv]")
default_attributes()
override_attributes()
