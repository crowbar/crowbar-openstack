def upgrade(ta, td, a, d)
  a["manila"] = ta["manila"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("manila")
  return a, d
end
