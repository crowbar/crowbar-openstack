def upgrade(ta, td, a, d)
  unless ta["db"].has_key? "max_pool_size"
    a["db"]["max_pool_size"] = ta["db"]["max_pool_size"]
  end
  unless ta["db"].has_key? "max_overflow"
    a["db"]["max_overflow"] = ta["db"]["maxoverflow"]
  end
  unless ta["db"].has_key? "pool_timeout"
    a["db"]["pool_timeout"] = ta["db"]["pool_timeout"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["db"].has_key? "max_pool_size"
    a["db"]["max_pool_size"].delete
  end
  unless ta["db"].has_key? "max_overflow"
    a["db"]["max_overflow"].delete
  end
  unless ta["db"].has_key? "pool_timeout"
    a["db"]["pool_timeout"].delete
  end
  return a, d
end
