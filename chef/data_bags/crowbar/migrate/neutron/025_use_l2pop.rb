def upgrade ta, td, a, d
  # Explicitly disable on upgrade as this can create some temporary networking
  # outage on existing deployments
  a["use_l2pop"] = false

  return a, d
end

def downgrade ta, td, a, d
  a.delete("use_l2pop")

  return a, d
end
