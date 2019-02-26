cert_path = node[:octavia][:certs][:cert_path]
already_created = ::File.exist?(cert_path + node[:octavia][:certs][:client_cert_and_key_path])
# TODO: also check if the CA defined by user has changed

template "/tmp/build_certs.sh" do
  source "build_certs.sh.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 0o700
  only_if { !already_created }
end

execute "Execute build certs" do
  command "./tmp/build_certs.sh"
  action :run
  only_if { !already_created }
end
