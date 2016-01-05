name "openstack-controller"
description "Generic OpenStack controller role"
run_list(
  "recipe[crowbar-openstack::controller]"
)
default_attributes
override_attributes
