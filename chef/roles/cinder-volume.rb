name "cinder-volume"
description "Cinder volume Role"
run_list("recipe[cinder::role_cinder_volume]")
default_attributes()
override_attributes()
