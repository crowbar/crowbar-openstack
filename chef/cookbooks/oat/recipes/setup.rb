#
# Cookbook Name:: Oat
# Recipe:: setup
#

include_recipe "#{@cookbook_name}::common"

#bash "tty linux setup" do
#  cwd "/tmp"
#  user "root"
#  code <<-EOH
#	mkdir -p /var/lib/oat/
#	curl #{node[:inteltxt][:tty_linux_image]} | tar xvz -C /tmp/
#	touch /var/lib/oat/tty_setup
#  EOH
#  not_if do File.exists?("/var/lib/oat/tty_setup") end
#end
