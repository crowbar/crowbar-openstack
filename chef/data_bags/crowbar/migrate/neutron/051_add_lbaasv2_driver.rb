def upgrade(ta, td, a, d)
  unless a.key? "lbaasv2_driver"
    a["lbaasv2_driver"] = ta["lbaasv2_driver"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "lbaasv2_driver"
    a.delete("lbaasv2_driver")
  end
  return a, d
end
