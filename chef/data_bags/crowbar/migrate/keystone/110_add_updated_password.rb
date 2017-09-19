def upgrade(ta, td, a, d)
  a["admin"]["updated_password"] = ta["admin"]["updated_password"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["admin"].delete("updated_password")
  return a, d
end
