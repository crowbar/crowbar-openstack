#should be executed before enabling tpm and itxt, but after reboot
package "tboot" do
  action :install
end

execute "switch_to_tboot" do
 command "mv /etc/grub.d/20_linux_tboot /etc/grub.d/09_linux_tboot ; update-grub"
 only_if { ::File.exists?("/etc/grub.d/20_linux_tboot") }
end
