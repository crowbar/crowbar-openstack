name "rabbitmq-server"
description "RabbiMQ server role - Setups the rabbitmq app"

run_list("recipe[rabbitmq::role_rabbitmq_server]")
