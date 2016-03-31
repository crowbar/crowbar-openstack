def upgrade(ta, td, a, d)
  a["api_db"] = ta["api_db"]

  if a["api_db"]["password"].nil? || a["api_db"]["password"].empty?
    service = ServiceObject.new "fake-logger"
    a["api_db"]["password"] = service.random_password
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("api_db")
  return a, d
end
