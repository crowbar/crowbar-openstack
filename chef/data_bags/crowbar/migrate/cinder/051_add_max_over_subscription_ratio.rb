def upgrade(ta, td, a, d)
  a['volume_defaults']['netapp']['max_over_subscription_ratio'] = \
    ta['volume_defaults']['netapp']['max_over_subscription_ratio']

  a['volumes'].each do |volume|
    next if volume['backend_driver'] != 'netapp'
    volume['netapp']['max_over_subscription_ratio'] = \
      ta['volume_defaults']['netapp']['max_over_subscription_ratio']
  end
  return a, d
end

def downgrade(ta, td, a, d)
  a['volume_defaults']['netapp'].delete('max_over_subscription_ratio')
  a['volumes'].each do |volume|
    next if volume['backend_driver'] != 'netapp'
    volume['netapp'].delete('max_over_subscription_ratio')
  end
  return a, d
end
