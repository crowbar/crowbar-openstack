def upgrade(ta, td, a, d)
  if a["secret_key"].nil? || a["secret_key"].empty?
    service = ServiceObject.new "fake-logger"
    a["secret_key"] = service.random_password
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("secret_key")
  return a, d
end
