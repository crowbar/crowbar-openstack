def upgrade ta, td, a, d
  a['volume_defaults']['rbd']['secret_uuid'] = ta['volume_defaults']['rbd']['secret_uuid']
  a['volumes'].each do |volume|
    next if volume['backend_driver'] != 'rbd'
    volume['rbd']['secret_uuid'] = `uuidgen`.strip
  end
  return a, d
end

def downgrade ta, td, a, d
  a['volume_defaults']['rbd'].delete 'secret_uuid'
  a['volumes'].each do |volume|
    next if volume['backend_driver'] != 'rbd'
    volume['rbd'].delete 'secret_uuid'
  end
  return a, d
end
