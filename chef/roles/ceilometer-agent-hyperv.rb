name "ceilometer-agent-hyperv"
description "Ceilometer Agent Role on HyperV Hosts"
run_list(
         "recipe[hyperv::do_setup]",
         "recipe[hyperv::do_ceilometer]"
)
default_attributes()
override_attributes()

