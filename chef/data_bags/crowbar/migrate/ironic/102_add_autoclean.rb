def upgrade(ta, td, a, d)
  a["automated_clean"] = ta["automated_clean"]
  return a, d
end

def downgrade(ta, td, a, d)
  if a["automated_clean"]
    a.delete("automated_clean")
  end
  return a, d
end
