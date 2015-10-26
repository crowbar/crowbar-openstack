name "manila-share"
description "Manila share Role"
run_list("recipe[manila::role_manila_share]")
default_attributes
override_attributes
