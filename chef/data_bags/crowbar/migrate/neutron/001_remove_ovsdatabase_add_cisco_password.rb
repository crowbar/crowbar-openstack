def upgrade ta, td, a, d
  # the ovs_database was never really used anywhere
  a['db'].delete 'ovs_database'
  a['db'].delete 'ovs_user'
  a['db'].delete 'ovs_password'
  # Setting this to false to keep existing non-ml2 setups working
  a['use_ml2'] = false
  return a, d
end

def downgrade ta, td, a, d
  a['db']['ovs_database'] = ta['db']['ovs_database']
  a['db']['ovs_user'] = ta['db']['ovs_user']
  a['db'].delete 'cisco_password'
  a.delete 'use_ml2'
  return a, d
end
