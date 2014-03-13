def upgrade ta, td, a, d
  service = ServiceObject.new "fake-logger"
  # old proposals had secrets created in the cookbook
  if a['db']['password'].nil? || a['db']['password'].empty?
    a['db']['password'] = service.random_password
  end
  a['metering_secret'] = service.random_password
  return a, d
end

def downgrade ta, td, a, d
  a.delete('metering_secret')
  return a, d
end
