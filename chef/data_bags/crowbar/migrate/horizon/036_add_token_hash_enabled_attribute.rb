def upgrade(ta, td, a, d)
  a["token_hash_enabled"] = ta["token_hash_enabled"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("token_hash_enabled")
  return a, d
end
