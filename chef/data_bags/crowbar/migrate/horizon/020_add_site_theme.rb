def upgrade ta, td, a, d
  unless a.key? "site_theme"
    a["site_theme"] = ta["site_theme"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta.key? "site_theme"
    a.delete("site_theme")
  end
  return a, d
end
