def upgrade(ta, td, a, d)
  a["cert"]["cert_manager_type"] = "local"
  return a, d
end

def downgrade(ta, td, a, d)
  a["cert"]["cert_manager_type"].delete("local")
  return a, d
end
