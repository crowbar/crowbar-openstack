def upgrade ta, td, a, d
  a['ha'] = ta['ha']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('ha')
  return a, d
end
