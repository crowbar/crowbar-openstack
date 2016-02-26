def upgrade(ta, td, a, d)
  a["scheduler"]["disk_allocation_ratio"] = ta["scheduler"]["disk_allocation_ratio"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["scheduler"].delete("disk_allocation_ratio")
  return a, d
end
