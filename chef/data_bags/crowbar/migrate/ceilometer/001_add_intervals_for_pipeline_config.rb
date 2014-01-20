def upgrade ta, td, a, d
  a['cpu_interval'] = ta['cpu_interval']
  a['meters_interval'] = ta['meters_interval']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('cpu_interval')
  a.delete('meters_interval')
  return a, d
end
