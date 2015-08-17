def upgrade ta, td, a, d
  a['trove'] = ta['trove']
  service = ServiceObject.new "fake-logger"
  a['trove']['password'] = service.random_password
  return a, d
end

def downgrade ta, td, a, d
  a.delete('trove')
  return a, d
end
