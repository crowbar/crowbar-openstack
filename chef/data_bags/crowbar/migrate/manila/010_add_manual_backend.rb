def upgrade(ta, td, a, d)
  unless a["share_defaults"].key? "manual"
    a["share_defaults"]["manual"] = ta["share_defaults"]["manual"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["share_defaults"].key? "manual"
    a["share_defaults"].delete("manual")
  end
  return a, d
end
