name "watcher-api"
description "Watcher Role - Node registered as a watcher api"
run_list("recipe[watcher::role_watcher_api]")
default_attributes
override_attributes
