def upgrade ta, td, a, d
  unless a.has_key? "max_pool_size"
    a["max_pool_size"] = ta["max_pool_size"]
  end
  unless a.has_key? "max_overflow"
    a["max_overflow"] = ta["max_overflow"]
  end
  unless a.has_key? "pool_timeout"
    a["pool_timeout"] = ta["pool_timeout"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.has_key? "max_pool_size"
    a.delete "max_pool_size"
  end
  unless ta.has_key? "max_overflow"
    a.delete "max_overflow"
  end
  unless ta.has_key? "pool_timeout"
    a.delete "pool_timeout"
  end
  return a, d
end
