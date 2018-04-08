def upgrade(ta, td, a, d)
  a["volume_defaults"]["pure"] = ta["volume_defaults"]["pure"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["volume_defaults"].delete("pure")
  return a, d
end
