Chef::Log.info "YYYY *************************************** Common *******************************"
include_recipe "#{@cookbook_name}::database"
include_recipe "#{@cookbook_name}::keystone"
include_recipe "#{@cookbook_name}::nova"

cookbook_file "#{node[:octavia][:sudoers_file]}" do
  source "sudoers"
  owner "root"
  group "root"
  mode 0440
end

group 'octavia' do
  group_name node[:octavia][:group]
  system true
end

user "octavia" do
  shell "/bin/bash"
  comment "Octavia user Server"
  gid node[:octavia][:group]
  system true
  supports manage_home: false
end

directory node[:octavia][:octavia_log_dir] do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end

directory "/etc/octavia/certs/private" do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end
