name "glance-server"
description "Glance Server Role - Image Registry and Delivery Service for the cloud"
run_list("recipe[glance::role_glance_server]")
default_attributes()
override_attributes()
