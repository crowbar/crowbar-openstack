name "murano-server"
description "Murano Server Role - Application Catalog for the cloud"
run_list("recipe[murano::role_murano_server]")
default_attributes
override_attributes
