def upgrade ta, td, a, d
  # we use a class variable to set the same key in the proposal and in the
  # role
  unless defined?(@@heat_auth_encryption_key)
    if a['auth_encryption_key'].empty?
      service = ServiceObject.new "fake-logger"
      encryption_key = service.random_password
      while encryption_key.length < 32 do
        encryption_key += service.random_password
      end
      @@heat_auth_encryption_key = encryption_key
    else
      @@heat_auth_encryption_key = a['auth_encryption_key']
    end
  end

  if a['auth_encryption_key'].empty?
    a['auth_encryption_key'] = @@heat_auth_encryption_key
  end

  return a, d
end

def downgrade ta, td, a, d
  return a, d
end
