def upgrade(ta, td, a, d)
  [
    "enable_cert_rules_for_protocols",
    "enable_ip_rules_for_protocols",
    "run_consistency_group_tests",
    "run_snapshot_tests",
    "enable_protocols"
  ].each do |key|
    a["manila"][key] = ta["manila"][key]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  [
    "enable_cert_rules_for_protocols",
    "enable_ip_rules_for_protocols",
    "run_consistency_group_tests",
    "run_snapshot_tests",
    "enable_protocols"
  ].each do |key|
    a["manila"].delete(key)
  end
  return a, d
end
