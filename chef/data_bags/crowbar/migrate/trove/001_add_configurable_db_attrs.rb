def upgrade ta, td, a, d
  unless a.key? "db"
    a["db"] = {}
    a["db"]["password"] = nil
    a["db"]["user"] = "trove"
    a["db"]["database"] = "trove"
  end
  return a, d
end

def downgrade ta, td, a, d
  a.delete "db"
  return a, d
end
