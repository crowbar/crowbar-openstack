def upgrade ta, td, a, d
  a['vmware'] = {}
  a['vmware']['user'] = ta['vmware']['user']
  a['vmware']['password'] = ta['vmware']['password']
  a['vmware']['controllers'] = ta['vmware']['controllers']
  a['vmware']['tz_uuid'] = ta['vmware']['tz_uuid']
  a['vmware']['l3_gw_uuid'] = ta['vmware']['l3_gw_uuid']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('vmware')
  return a, d
end
