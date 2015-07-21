def upgrade(ta, td, a, d)
  a["zvm"] = ta["zvm"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("zvm")
  return a, d
end
