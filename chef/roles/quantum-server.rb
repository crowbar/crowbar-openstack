name "quantum-server"
description "Quantum server"

run_list(
  "recipe[quantum::server]",
  "recipe[quantum::monitor]"
)

