def upgrade(ta, td, a, d)
  a["conversion"] = ta["conversion"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("conversion")
  return a, d
end
