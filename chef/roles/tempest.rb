name "tempest"
description "Tempest Role - does tempest installation"
run_list(
        "recipe[tempest::install]",
        "recipe[tempest::config]"
)
default_attributes()
override_attributes()
