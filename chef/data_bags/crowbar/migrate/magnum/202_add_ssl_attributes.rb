def upgrade(ta, td, a, d)
  a["ssl"] = {}
  a["ssl"]["certfile"]       = ta["ssl"]["certfile"]
  a["ssl"]["keyfile"]        = ta["ssl"]["keyfile"]
  a["ssl"]["generate_certs"] = ta["ssl"]["generate_certs"]
  a["ssl"]["insecure"]       = ta["ssl"]["insecure"]
  a["ssl"]["cert_required"]  = ta["ssl"]["cert_required"]
  a["ssl"]["ca_certs"]       = ta["ssl"]["ca_certs"]
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("ssl")
  return a, d
end
