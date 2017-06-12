def upgrade(ta, td, a, d)
  a["vmware_dvs"] = ta["vmware_dvs"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("vmware_dvs")
  return a, d
end
