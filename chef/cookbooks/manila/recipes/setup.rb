#
# Cookbook Name:: Manila
# Recipe:: setup
#

include_recipe "#{@cookbook_name}::common"

bash "tty linux setup" do
  cwd "/tmp"
  user "root"
  code <<-EOH
  mkdir -p /var/lib/manila/
  curl #{node[:manila][:tty_linux_image]} | tar xvz -C /tmp/
  touch /var/lib/manila/tty_setup
  EOH
  not_if { File.exist?("/var/lib/manila/tty_setup") }
end
