def upgrade(ta, td, a, d)
  a["placement_db"] = ta["placement_db"]

  if a["placement_db"]["password"].nil? || a["placement_db"]["password"].empty?
    service = ServiceObject.new "fake-logger"
    a["placement_db"]["password"] = service.random_password
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("placement_db")
  return a, d
end
