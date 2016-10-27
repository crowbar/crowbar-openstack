def upgrade(ta, td, a, d)
  a["ssl"].delete("cert_required")
  return a, d
end

def downgrade(ta, td, a, d)
  a["ssl"]["cert_required"] = ta["ssl"]["cert_required"]
  return a, d
end
