def upgrade(ta, td, a, d)
  ["tcp_listen_options", "collect_statistics_interval"].each do |option|
    a[option] = ta[option] unless a.key?(option)
  end
  return a, d
end

def downgrade(ta, td, a, d)
  ["tcp_listen_options", "collect_statistics_interval"].each do |option|
    a.delete(option) unless ta.key?(option)
  end
  return a, d
end
