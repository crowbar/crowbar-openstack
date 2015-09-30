default[:tempest][:tempest_path] = "/opt/tempest"

if node[:platform_family] == "suse"
  default[:tempest][:heat_test_image_name] = "SLE11SP3-x86_64-cfntools"
  default[:tempest][:tempest_path] = "/var/lib/openstack-tempest-test"
end
