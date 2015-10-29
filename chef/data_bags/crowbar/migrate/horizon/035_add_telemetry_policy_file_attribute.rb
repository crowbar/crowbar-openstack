def upgrade(ta, td, a, d)
  a["policy_file"]["telemetry"] = ta["policy_file"]["telemetry"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["policy_file"].delete("telemetry")
  return a, d
end
