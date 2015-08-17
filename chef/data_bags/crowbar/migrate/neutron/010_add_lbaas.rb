def upgrade ta, td, a, d
  unless a.include?('use_lbaas')
    a['use_lbaas'] = ta['use_lbaas']
  end
  return a, d
end

def downgrade ta, td, a, d
  a.delete('use_lbaas')
  return a, d
end
