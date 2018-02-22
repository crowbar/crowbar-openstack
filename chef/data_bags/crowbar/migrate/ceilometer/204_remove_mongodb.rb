def upgrade(ta, td, a, d)
  a.delete("use_mongodb")
  return a, d
end

def downgrade(ta, td, a, d)
  a["use_mongodb"] = ta["use_mongodb"]
  return a, d
end
