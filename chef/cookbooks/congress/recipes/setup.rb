#
# Cookbook Name:: Congress
# Recipe:: setup
#

include_recipe "#{@cookbook_name}::common"

bash "tty linux setup" do
  cwd "/tmp"
  user "root"
  code <<-EOH
  mkdir -p /var/lib/congress/
  curl #{node[:congress][:tty_linux_image]} | tar xvz -C /tmp/
  touch /var/lib/congress/tty_setup
  EOH
  not_if { File.exists?("/var/lib/congress/tty_setup") }
end
