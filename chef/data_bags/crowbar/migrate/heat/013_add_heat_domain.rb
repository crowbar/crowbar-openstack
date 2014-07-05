def upgrade ta, td, a, d
  a['stack_domain_admin'] = ta['stack_domain_admin']
  a['stack_domain_admin_password'] = ta['stack_domain_admin_password']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('stack_domain_admin')
  a.delete('stack_domain_admin_password')
  return a, d
end
