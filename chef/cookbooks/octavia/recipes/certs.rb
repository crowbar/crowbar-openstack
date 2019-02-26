cert_path = node[:octavia][:certs][:cert_path]
already_created = ::File.exist?(cert_path + node[:octavia][:certs][:server_ca_cert_path])
# TODO: also check if the CA defined by user has changed

template cert_path + "/openssl.cnf" do
  source "openssl.cnf.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 0o600
  only_if { !already_created }
end

api_list = search(:node, "roles:octavia-api") || []
worker_list = search(:node, "roles:octavia-worker") || []
healthmanager_list = search(:node, "roles:octavia-health-manager") || []
housekeeping_list = search(:node, "roles:octavia-housekeeping") || []
list = api_list + worker_list + healthmanager_list + housekeeping_list

node_list = []
list.each do |e|
  unless e.name == node.name
    node_list << e.name unless node_list.include?(e.name)
  end
end

node[:octavia][:tmp][:node_list] = node_list

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
