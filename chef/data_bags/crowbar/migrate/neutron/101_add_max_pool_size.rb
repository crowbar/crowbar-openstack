def upgrade(ta, td, a, d)
  a["sql"]["max_pool_size"] = ta["sql"]["max_pool_size"] unless a["sql"].key?("max_pool_size")

  return a, d
end

def downgrade(ta, td, a, d)
  a["sql"].delete("max_pool_size")

  return a, d
end
