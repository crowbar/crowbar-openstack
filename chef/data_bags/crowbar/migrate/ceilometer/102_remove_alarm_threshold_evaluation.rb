def upgrade(ta, td, a, d)
  a.delete("alarm_threshold_evaluation_interval")
  return a, d
end

def downgrade(ta, td, a, d)
  a["alarm_threshold_evaluation_interval"] = ta["alarm_threshold_evaluation_interval"]
  return a, d
end
