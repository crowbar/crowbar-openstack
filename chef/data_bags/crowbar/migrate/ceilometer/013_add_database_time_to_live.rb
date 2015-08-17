def upgrade ta, td, a, d
  a['database'] = ta['database']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('database')
  return a, d
end
