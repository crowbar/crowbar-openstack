def upgrade(ta, td, a, d)
  a["apache"]["ssl_protocol"] = "all -SSLv3"
  return a, d
end

def downgrade(ta, td, a, d)
  a["apache"].delete("ssl_protocol")
  return a, d
end
