def upgrade(ta, td, a, d)
  a["identity"]["password_hash_algorithm"] = ta["identity"]["password_hash_algorithm"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["identity"].delete("password_hash_algorithm")
  if a["identity"].key?("password_hash_rounds")
    a["identity"].delete("password_hash_rounds")
  end
  return a, d
end
