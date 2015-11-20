def upgrade ta, td, a, d
  unless a["api"].key? "region"
    a["api"]["region"] = ta["api"]["region"]
  end
  return a, d
end

def downgrade ta, td, a, d
  unless ta["api"].key? "region"
    a["api"].delete("region")
  end
  return a, d
end
