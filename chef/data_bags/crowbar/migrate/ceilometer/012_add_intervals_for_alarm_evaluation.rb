def upgrade ta, td, a, d
  a['alarm_threshold_evaluation_interval'] = [ a['cpu_interval'],
                                               a['disk_interval'],
                                               a['network_interval'],
                                               a['meters_interval'] ].max
  return a, d
end

def downgrade ta, td, a, d
  a.delete('alarm_threshold_evaluation_interval')
  return a, d
end
