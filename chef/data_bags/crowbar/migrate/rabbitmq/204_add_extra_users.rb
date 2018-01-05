def upgrade(ta, td, a, d)
  a["extra_users"] = ta["extra_users"] unless a["extra_users"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("extra_users") unless ta.key?("extra_users")
  return a, d
end
