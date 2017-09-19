def upgrade(ta, td, a, d)
  a["enabled_drivers"] = ta["enabled_drivers"]
  return a, d
end

def downgrade(ta, td, a, d)
  if a["enabled_drivers"]
    a.delete("enabled_drivers")
  end
  return a, d
end
