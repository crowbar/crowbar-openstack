directory node[:octavia][:certs][:cert_path] do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end

template node[:octavia][:certs][:cert_path] + "/openssl.cnf" do
  source "openssl.cnf.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00600
end

template "/tmp/build_certs.sh" do
  source "build_certs.sh.erb"
  owner node[:octavia][:user]
  group node[:octavia][:group]
  mode 00700
end

execute 'apache_configtest' do
  command './tmp/build_certs.sh'
  action :run
  #only_if { !node[:aodh][:db_synced] && (!ha_enabled || CrowbarPacemakerHelper.is_cluster_founder?(node)) }
end

ruby_block "Store certificates" do
  block do
    #server_ca_cert = ::File.read(node[:octavia][:certs][:server_ca_cert])
    # node[:octavia][:certs][:raw] = {
    #   :server_ca_cert => ::File.read(node[:octavia][:certs][:cert_path] + node[:octavia][:certs][:server_ca_cert_path]),
    #   :server_ca_key => ::File.read(node[:octavia][:certs][:cert_path] + node[:octavia][:certs][:server_ca_key_path]),
    #   :client_ca => ::File.read(node[:octavia][:certs][:cert_path] + node[:octavia][:certs][:client_ca_cert_path]),
    #   :client_cert_and_key => ::File.read(node[:octavia][:certs][:cert_path] + node[:octavia][:certs][:client_cert_and_key_path]),
    # }


    Chef::Log.info "YYYY *************************************** CERTS *******************************"
    server_ca_cert = ::File.read(node[:octavia][:certs][:server_ca_cert])

    item = {
          "id" => "octavia",
          "server_ca_cert" => server_ca_cert
        }

    Chef::Log.info "YYYY #{server_ca_cert} #{item}"

    databag_item = Chef::DataBagItem.new
      Chef::Log.info "YYYY 1"
    databag_item.data_bag("crowbar")
      Chef::Log.info "YYYY 2"
    databag_item.raw_data = item
      Chef::Log.info "YYYY 3"
    databag_item.save
  end
end


ruby_block "read certs" do
  block do
    Chef::Log.info "YYYY cert #{node[:octavia][:certs][:raw]}"
  end
end
