def upgrade ta, td, a, d
  a['gre'] = ta['gre']

  return a, d
end

def downgrade ta, td, a, d
  a.delete('gre')

  return a, d
end
