def upgrade(ta, td, a, d)
  a["uid"] = ta["uid"]
  a["gid"] = ta["gid"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("uid")
  a.delete("gid")
  return a, d
end
