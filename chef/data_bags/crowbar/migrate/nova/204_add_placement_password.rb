def upgrade(ta, td, a, d)
  if a["placement_service_password"].nil? || a["placement_service_password"].empty?
    service = ServiceObject.new "fake-logger"
    a["placement_service_password"] = service.random_password
  end

  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("placement_service_password")
  return a, d
end
