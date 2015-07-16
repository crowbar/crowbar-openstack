def upgrade ta, td, a, d
  a['vmware']['port'] = ta['vmware']['port']
  return a, d
end

def downgrade ta, td, a, d
  a['vmware'].delete 'port'
  return a, d
end
