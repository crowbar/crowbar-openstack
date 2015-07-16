name "ceilometer-swift-proxy-middleware"
description "Ceilometer Swift Support"
run_list(
         "recipe[ceilometer::swift]"
)
default_attributes()
override_attributes()
