def upgrade ta, td, a, d
  a['use_virtualenv'] = ta['use_virtualenv']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('use_virtualenv')
  return a, d
end
