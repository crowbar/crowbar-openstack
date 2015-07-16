def upgrade ta, td, a, d
  # we use a class variable to set the same key in the proposal and in the
  # role
  unless defined?(@@heat_stack_domain_admin_password)
    if a['stack_domain_admin_password'].empty?
      service = ServiceObject.new "fake-logger"
      @@heat_stack_domain_admin_password = service.random_password
    else
      @@heat_stack_domain_admin_password = a['stack_domain_admin_password']
    end
  end

  if a['stack_domain_admin_password'].empty?
    a['stack_domain_admin_password'] = @@heat_stack_domain_admin_password
  end

  return a, d
end

def downgrade ta, td, a, d
  return a, d
end
