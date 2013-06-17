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
  cert_f = "/tmp/cer-192.168.124.8.cer"


  ruby_block "invoke_wsman" do
    block do
      require 'xml'

      system("echo | openssl s_client -connect #{ip}:443 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >#{cert_f} 2>&1")
      3.times do
        wsm_r=%x{wsman invoke -a SetAttribute 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=TpmSecurity' -k 'AttributeValue=OnPbm'}
        return_val=XML::Parser.string(wsm_r).parse.find('//n1:ReturnValue').first.content
        if return_val != "0"
          puts "Command:"
          puts %Q{wsman invoke -a SetAttribute 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=TpmSecurity' -k 'AttributeValue=OnPbm'}
          puts "Returned:"
          puts wsm_r
          sleep(3)
        else
          break
        end
      end
      3.times do
        wsm_r=%x{wsman invoke -a SetAttribute "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}" -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=TpmActivation' -k 'AttributeValue=Activate'}
        return_val=XML::Parser.string(wsm_r).parse.find('//n1:ReturnValue').first.content
        if return_val != "0"
          puts "Command:"
          puts %Q{wsman invoke -a SetAttribute "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}" -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=TpmActivation' -k 'AttributeValue=Activate'}
          puts "Returned:"
          puts wsm_r
          sleep(3)
        else
          break
        end
      end
      3.times do
        wsm_r=%x{wsman invoke -a SetAttribute "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=IntelTxt' -k 'AttributeValue=On'}
        return_val=XML::Parser.string(wsm_r).parse.find('//n1:ReturnValue').first.content
        if return_val != "0"
          puts "Command:"
          puts %Q{wsman invoke -a SetAttribute "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=IntelTxt' -k 'AttributeValue=On'}
          puts "Returned:"
          puts wsm_r
          sleep(3)
        else
          break
        end
      end
      #wsman invoke -a CreateRebootJob "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_SoftwareInstallationService?CreationClassName=DCIM_SoftwareInstallationService,SystemCreationClassName=DCIM_ComputerSystem,SystemName=IDRAC:ID,Name=SoftwareUpdate" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'RebootJobType=2'
      3.times do
        wsm_r=%x{wsman invoke -a CreateTargetedConfigJob "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'RebootJobType=2' -k 'ScheduledStartTime=TIME_NOW'}
        return_val=XML::Parser.string(wsm_r).parse.find('//n1:ReturnValue').first.content
         if return_val != "0"
          puts "Command:"
          puts %Q{wsman invoke -a CreateTargetedConfigJob "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService" -h #{ip} -P 443 -u #{user} -p "#{password}"  -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'RebootJobType=2' -k 'ScheduledStartTime=TIME_NOW'}
          puts "Returned:"
          puts wsm_r
          sleep(3)
        else
          break
        end
      end
    end
    action :create
  end

# unless ["complete","rebooting"].include? node[:reboot]
  node[:reboot] = "require"
  node.save
# end

end
