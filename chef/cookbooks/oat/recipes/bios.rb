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
      require 'xml'

      system("echo | openssl s_client -connect #{ip}:443 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >#{cert_f} 2>&1")

      def set_value(key, value, ip, user, password, cert_f)
        puts "Setting #{key} to #{value}"
        3.times do |attemp|
          wsm_r=%x{wsman invoke -a SetAttribute 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=#{key}' -k 'AttributeValue=#{value}'}
          return_val=XML::Parser.string(wsm_r).parse.find('//n1:ReturnValue').first.content
          if return_val != "0"
            puts "Command:"
            puts %Q{wsman invoke -a SetAttribute 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=#{key}' -k 'AttributeValue=#{value}'}
            puts "Returned:"
            puts wsm_r
            sleep(10)
            if attemp == 2
              return false
            end
          else
            break
          end
        end
        return true
      end

      def check_val(key, value, ip, user, password, cert_f)
        3.times do
          begin
            enum_r=%x{wsman enumerate 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BIOSEnumeration' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V}
            doc=XML::Parser.string(enum_r).parse
            wsnode=doc.find("//n1:AttributeName[text()='#{key}']").first.parent
            doc.root=wsnode
            doc=XML::XPath::Context.new(doc)
            doc.register_namespace("n1","http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_BIOSEnumeration")
            if doc.find('//n1:PendingValue').first.content == value or doc.find('//n1:CurrentValue').first.content == value
              return true
            else
              return false
            end
          rescue
            puts "Failed during comparing #{key} on #{value}"
          end
        end
        return false
      end

      if not check_val('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
        set_value('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
      end
      if not check_val('TpmActivation', 'Activate', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
        3.times do
          if not set_value('TpmActivation', 'Activate', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
            set_value('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
          else
            break
          end
        end
      end
      if not check_val('IntelTxt', 'On', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
        3.times do
          if not set_value('IntelTxt', 'On', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
            set_value('TpmSecurity', 'OnPbm', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
            set_value('TpmActivation', 'Activate', "#{ip}", "#{user}", "#{password}", "#{cert_f}")
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
