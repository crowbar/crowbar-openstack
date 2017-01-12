def upgrade(ta, td, a, d)
  unless a.key? "f5"
    a["f5"] = ta["f5"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta.key? "f5"
    a.delete("f5")
  end
  return a, d
end
