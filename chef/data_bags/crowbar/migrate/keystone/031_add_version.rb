def upgrade ta, td, a, d
  unless a["api"].key? "version"
    a["api"]["version"] = ta["api"]["version"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta["api"].key? "version"
    a["api"].delete("version")
  end
  return a, d
end
