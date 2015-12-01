default[:tempest][:tempest_path] = "/opt/tempest"

if node[:platform_family] == "suse"
  default[:tempest][:tempest_path] = "/var/lib/openstack-tempest-test"
end
