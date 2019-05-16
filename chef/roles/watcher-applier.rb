name "watcher-applier"
description "Watcher Role - Node registered as a watcher applier"
run_list("recipe[watcher::role_watcher_applier]")
default_attributes
override_attributes
