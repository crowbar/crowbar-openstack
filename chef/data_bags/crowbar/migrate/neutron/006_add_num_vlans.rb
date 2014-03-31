def upgrade ta, td, a, d
  a['num_vlans'] = ta['num_vlans']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('num_vlans')
  return a, d
end
