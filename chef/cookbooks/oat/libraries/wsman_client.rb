class Wsm

def set_value(key, value, ip, user, password, cert_f)
        require 'xml'
        puts "Setting #{key} to #{value}"
        3.times do |attemp|
          inv_r=%x{wsman invoke -a SetAttribute 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=#{key}' -k 'AttributeValue=#{value}'}
          return_val=XML::Parser.string(inv_r).parse.find('//n1:ReturnValue').first.content
          if return_val != "0"
            puts "Command:"
            puts %Q{wsman invoke -a SetAttribute 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/DCIM_BIOSService?SystemCreationClassName=DCIM_ComputerSystem,CreationClassName=DCIM_BIOSService,SystemName=DCIM:ComputerSystem,Name=DCIM:BIOSService' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V -k 'Target=BIOS.Setup.1-1' -k 'AttributeName=#{key}' -k 'AttributeValue=#{value}'}
            puts "Returned:"
            puts inv_r
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
        require 'xml'
        3.times do
          begin
            enum_r=%x{wsman enumerate 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/root/dcim/DCIM_BIOSEnumeration' -h #{ip} -P 443 -u #{user} -p '#{password}' -c #{cert_f} -N root/dcim -v -o -j utf-8 -y basic -m 512 -V}
            doc=XML::Parser.string(enum_r).parse
            wsnode=doc.find("//n1:AttributeName[text()='#{key}']").first.parent
            wsstr=wsnode.to_s

            #Commented code is a proper way to do this thing, but due to ruby xml awesomness it caused chef to segfault, so we partialy using regexp to parse damn xml.

            #docm.root=wsnode

            #docm=XML::XPath::Context.new(docm)
            #docm.register_namespace("n1","http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_BIOSEnumeration")
            #puts docm.find('//n1:PendingValue').first.content
            #puts docm.find('//n1:CurrentValue').first.content
            #if doc.find('//n1:PendingValue').first.content == value or doc.find('//n1:CurrentValue').first.content == value

            #doc.root=wsnode
            #doc=XML::XPath::Context.new(doc)
            #doc.register_namespace("n1","http://schemas.dell.com/wbem/wscim/1/cim-schema/2/DCIM_BIOSEnumeration")
            #if doc.find('//n1:PendingValue').first.content == value or doc.find('//n1:CurrentValue').first.content == value
            if wsstr.match("PendingValue.*#{value}.*PendingValue") or wsstr.match("CurrentValue.*#{value}.*CurrentValue")
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


end

#Xyzzy.new.do_it
