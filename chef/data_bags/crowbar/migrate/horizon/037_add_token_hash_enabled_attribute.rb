def upgrade(ta, td, a, d)
  a["apache"]["generate_certs"] = ta["apache"]["generate_certs"]
  return a, d
end

def downgrade(ta, td, a, d)
  a["apache"].delete "generate_certs"
  return a, d
end
