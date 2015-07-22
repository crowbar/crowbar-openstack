name "manila-share"
description "Manila share Role"
run_list(
  "recipe[manila::share]"
)
default_attributes
override_attributes
