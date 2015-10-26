name "nova-controller"

description "Installs requirements to run the Controller node in a Nova cluster"
run_list("recipe[nova::role_nova_controller]")
