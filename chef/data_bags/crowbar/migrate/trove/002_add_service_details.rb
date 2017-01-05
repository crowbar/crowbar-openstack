def upgrade(ta, td, a, d)
  # Use a class variable, since migrations are run twice.
  unless defined?(@@trove_service_password)
    service = ServiceObject.new "fake-logger"
    @@trove_service_password = service.random_password
  end
  a["service_user"] = ta["service_user"]
  a["service_password"] = @@trove_service_password
  return a, d
end

def downgrade(ta, td, a, d)
  a.delete("service_user")
  a.delete("service_password")
  return a, d
end
