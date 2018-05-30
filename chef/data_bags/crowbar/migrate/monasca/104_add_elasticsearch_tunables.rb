def upgrade(ta, td, a, d)
  # this migration already happened if the tsdb key exists
  return a, d if a["elasticsearch"].key?("tunables")

  a["elasticsearch"]["tunables"] = ta["elasticsearch"]["tunables"]

  return a, d
end

def downgrade(ta, td, a, d)
  a["elasticsearch"].delete("tunables")

  return a, d
end
