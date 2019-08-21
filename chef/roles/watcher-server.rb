name "watcher-server"
description "Watcher Server Role - Watcher API, Decision Engine, and Applier Services for the cloud"
run_list("recipe[watcher::role_watcher_server]")
default_attributes
override_attributes
