#
# Cookbook Name:: Cinder
# Recipe:: setup
#

include_recipe "#{@cookbook_name}::common"

bash "tty linux setup" do
  cwd "/tmp"
  user "root"
  code <<-EOH
	mkdir -p /var/lib/cinder/
	curl #{node[:cinder][:tty_linux_image]} | tar xvz -C /tmp/
	touch /var/lib/cinder/tty_setup
  EOH
  not_if do File.exists?("/var/lib/cinder/tty_setup") end
end
