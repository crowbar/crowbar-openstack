def upgrade(ta, td, a, d)
  unless a["volume_defaults"].key?("hitachi")
    a["volume_defaults"]["hitachi"] = ta["volume_defaults"]["hitachi"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  if a["volume_defaults"].key?("hitachi")
    a["volume_defaults"].delete("hitachi")
  end
  return a, d
end
