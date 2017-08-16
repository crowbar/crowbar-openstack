def upgrade(ta, td, a, d)
  a.delete("verbose")
  return a, d

def downgrade(ta, td, a, d)
  a["verbose"] = ta["verbose"]
  return a, d
