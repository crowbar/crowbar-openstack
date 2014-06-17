def upgrade ta, td, a, d
  a['auth_encryption_key'] = ta['auth_encryption_key']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('auth_encryption_key')
  return a, d
end
