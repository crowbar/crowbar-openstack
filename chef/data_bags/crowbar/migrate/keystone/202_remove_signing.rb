def upgrade(ta, td, a, d)
  a["token_format"] = a["signing"]["token_format"]
  a.delete("signing")
  return a, d
end

def downgrade(ta, td, a, d)
  a["signing"] = {
    "certfile" => "/etc/keystone/ssl/certs/signing_cert.pem",
    "keyfile" => "/etc/keystone/ssl/private/signing_key.pem",
    "ca_certs" => "/etc/keystone/ssl/certs/ca.pem",
    "token_format" => a["token_format"]
  }
  a.delete("token_format")
  return a, d
end
