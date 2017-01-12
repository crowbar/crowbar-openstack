def upgrade(ta, td, a, d)
  a.delete("use_lbaasv2")
  return a, d
end

def downgrade(ta, td, a, d)
  if ta.key? "use_lbaasv2"
    a["use_lbaasv2"] = ta["use_lbaasv2"]
  end
  return a, d
end
