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


template "/tmp/build_ca_certs.sh" do
  source "build_ca_certs.sh.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 0o700
  only_if { !already_created }
end

execute "Execute build CA certs" do
  command "./tmp/build_ca_certs.sh"
  action :run
  only_if { !already_created }
end

nodes = CrowbarPacemakerHelper.cluster_nodes(node, "octavia-certificates-sharing")
node_list = []
nodes.each do |e|
  unless e.name == node.name
    node_list << e.name unless node_list.include?(e.name)
  end
end

template "/tmp/distribute_ca_certs.sh" do
  source "distribute_ca_certs.sh.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 0o700
  variables(
    node_list: node_list
  )
end

execute "Distribute certs" do
  command "./tmp/distribute_ca_certs.sh"
  action :run
end
