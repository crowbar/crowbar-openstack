name "quantum-server"
description "Quantum server"

run_list(
  "recipe[quantum::server]",
  "recipe[quantum::monitor]"
)

override_attributes "quantum" => { "quantum_server" => "true" }
