def upgrade(ta, td, a, d)
  unless a["share_defaults"].key? "hitachi"
    a["share_defaults"]["hitachi"] = ta["share_defaults"]["hitachi"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["share_defaults"].key? "hitachi"
    a["share_defaults"].delete("hitachi")
  end
  return a, d
end
