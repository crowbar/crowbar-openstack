def upgrade ta, td, a, d
  a['volume_defaults']['vmware']['volume_folder'] = a['volume_defaults']['vmware']['volume']
  a['volume_defaults']['vmware'].delete('volume')

  a['volumes'].each do |volume|
    next if volume['backend_driver'] != 'vmware'
    volume['vmware']['volume_folder'] = volume['vmware']['volume']
    volume['vmware'].delete('volume')
  end

  return a, d
end


def downgrade ta, td, a, d
  a['volume_defaults']['vmware']['volume'] = a['volume_defaults']['vmware']['volume_folder']
  a['volume_defaults']['vmware'].delete('volume_folder')

  a['volumes'].each do |volume|
    next if volume['backend_driver'] != 'vmware'
    volume['vmware']['volume'] = volume['vmware']['volume_folder']
    volume['vmware'].delete('volume_folder')
  end

  return a, d
end
