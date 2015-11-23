def upgrade(ta, td, a, d)
  unless a["db"].key? "max_pool_size"
    a["db"]["max_pool_size"] = ta["db"]["max_pool_size"]
  end
  unless a["db"].key? "max_overflow"
    a["db"]["max_overflow"] = ta["db"]["max_overflow"]
  end
  unless a["db"].key? "pool_timeout"
    a["db"]["pool_timeout"] = ta["db"]["pool_timeout"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["db"].key? "max_pool_size"
    a["db"].delete "max_pool_size"
  end
  unless ta["db"].key? "max_overflow"
    a["db"].delete "max_overflow"
  end
  unless ta["db"].key? "pool_timeout"
    a["db"].delete "pool_timeout"
  end
  return a, d
end
