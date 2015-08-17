def upgrade ta, td, a, d
  # we use a class variable to set the same key in the proposal and in the
  # role
  a['stack_domain_admin'] = ta['stack_domain_admin']
  unless defined?(@@heat_stack_domain_admin_password)
    service = ServiceObject.new "fake-logger"
    @@heat_stack_domain_admin_password = service.random_password
  end
  a['stack_domain_admin_password'] = @@heat_stack_domain_admin_password
  return a, d
end

def downgrade ta, td, a, d
  a.delete('stack_domain_admin')
  a.delete('stack_domain_admin_password')
  return a, d
end
