def upgrade(ta, td, a, d)
  a["magnum"] = ta["magnum"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("magnum")
  return a, d
end
