def upgrade ta, td, a, d
  a['db'].delete 'cisco_database'
  a['db'].delete 'cisco_user'
  a['db'].delete 'cisco_password'
  return a, d
end

def downgrade ta, td, a, d
  a['db']['cisco_database'] = ta['db']['cisco_database']
  a['db']['cisco_user'] = ta['db']['cisco_user']
  # leave password empty, it's optional
  return a, d
end
