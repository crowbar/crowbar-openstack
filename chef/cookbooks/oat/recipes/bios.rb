#some magic should be here wich able to configure bios and pass control to tboot.rb


tpm_active = File.exist?("/sys/class/misc/tpm0/device/active") ? File.read("/sys/class/misc/tpm0/device/active").to_i : 0
tpm_enabled = File.exist?("/sys/class/misc/tpm0/device/enabled") ? File.read("/sys/class/misc/tpm0/device/enabled").to_i : 0
if tpm_enabled != 1 and tpm_active != 1
  package "wsmancli" do
    options "--force-yes"
  end

  ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "bmc").address
  user = node["ipmi"]["bmc_user"] rescue "root"
  password = node["ipmi"]["bmc_password"] rescue "cr0wBar!"
  cert_f = "/tmp/cer-#{ip}.cer"


  ruby_block "invoke_wsman" do
    block do

      system("echo | openssl s_client -connect #{ip}:443 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >#{cert_f} 2>&1")

      cl=Wsm.new
      
      if not cl.check_val('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
        cl.set_value('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
      end
      if not cl.check_val('TpmActivation', 'Activate', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
        3.times do
          if not cl.set_value('TpmActivation', 'Activate', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
            cl.set_value('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
          else
            break
          end
        end
      end
      if not cl.check_val('IntelTxt', 'On', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
        3.times do
          if not cl.set_value('IntelTxt', 'On', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
            cl.set_value('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
            cl.set_value('TpmActivation', 'Activate', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
          else
            break
          end
        end
      end
      wsm_r=%x{wsman invoke -a CreateTargetedConfigJob "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'RebootJobType=2' -k 'ScheduledStartTime=TIME_NOW'}
      puts "Command:"
      puts %Q{wsman invoke -a CreateTargetedConfigJob "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'RebootJobType=2' -k 'ScheduledStartTime=TIME_NOW'}
      puts "Returned:"
      puts wsm_r
      sleep(10)
    end
    action :create
  end

# unless ["complete","rebooting"].include? node[:reboot]
  node[:reboot] = "require"
  node.save
# end

end
