def upgrade(ta, td, a, d)
  a["use_serial"] = ta["use_serial"]

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("use_serial")

  return a, d
end
