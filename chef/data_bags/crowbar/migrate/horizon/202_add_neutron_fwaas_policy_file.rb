def upgrade(ta, td, a, d)
  a["policy_file"]["neutron_fwaas"] = ta["policy_file"]["neutron_fwaas"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["policy_file"].delete("neutron_fwaas")
  return a, d
end
