default[:tempest][:use_virtualenv] = false

if node.platform == "suse"
  default[:tempest][:heat_test_image_name] = "SLE11SP3-x86_64-cfntools"
end
