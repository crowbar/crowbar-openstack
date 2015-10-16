default[:memcached][:memory] = 64
default[:memcached][:port] = 11211
default[:memcached][:listen] = "0.0.0.0"
default[:memcached][:daemonize] = true

case node[:platform_family]
when "suse"
  default[:memcached][:user] = "memcached"
  default[:memcached][:daemonize] = false unless (node[:platform] == "suse" && node[:platform_version].to_f < 12.0)
else
  default[:memcached][:user] = "nobody"
end
