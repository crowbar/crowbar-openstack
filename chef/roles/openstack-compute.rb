name "openstack-compute"
description "Generic OpenStack compute role"
run_list(
  "recipe[crowbar-openstack::compute]"
)
default_attributes
override_attributes
