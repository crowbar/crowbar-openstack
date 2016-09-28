name "ec2-api"
description "Installs and runs the EC2 api"
run_list(
  "recipe[nova::role_ec2_api]",
)
