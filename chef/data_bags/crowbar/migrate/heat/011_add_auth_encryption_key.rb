def upgrade ta, td, a, d
  # we use a class variable to set the same key in the proposal and in the
  # role
  unless defined?(@@heat_auth_encryption_key)
    service = ServiceObject.new "fake-logger"
    @@heat_auth_encryption_key = service.random_password
  end

  a['auth_encryption_key'] = @@heat_auth_encryption_key
  return a, d
end

def downgrade ta, td, a, d
  a.delete('auth_encryption_key')
  return a, d
end
