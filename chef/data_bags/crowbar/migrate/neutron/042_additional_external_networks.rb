def upgrade ta, td, a, d
  a['additional_external_networks'] = ta['additional_external_networks']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('additional_external_networks')
  return a, d
end
