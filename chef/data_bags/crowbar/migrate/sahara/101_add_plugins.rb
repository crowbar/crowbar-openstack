def upgrade(ta, td, a, d)
  unless a.key? "plugins"
    a["plugins"] = ta["plugins"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "plugins"
    a.delete("plugins")
  end
  return a, d
end
