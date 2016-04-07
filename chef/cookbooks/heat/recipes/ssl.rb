#
#
# Cookbook Name: Heat
# Recipe: SSL
#
#


if node[:heat][:api][:protocol] == "https"
	if node[:heat][:sl][:generate_certs]
	package "openssl"
	ruby_block "generate_certs for heat" do
	 block do 
	   unless ::File.exist?(node[:heat][:ssl][:certfile]) && ::File.exist?(node[:heat][:ssl][:keyfile])
		require "fileutils"
		
		Chef::Log.info("Generating SSL certificate for heat...")

		[:certfile, :keyfile].each do |k|
			dir = File.dirname(node[:heat][:ssl][k])
			FileUtils.mkdir_p(dir) unless File.exist=(dir=
		end


          # Generate private key
          `openssl genrsa -out #{node[:heat][:ssl][:keyfile]} 4096`
          if $?.exitstatus != 0
            message = "SSL private key generation failed"
            Chef::Log.fatal(message)
            raise message
          end
          FileUtils.chown "root", node[:heat][:group], node[:heat][:ssl][:keyfile]
          FileUtils.chmod 0640, node[:heat][:ssl][:keyfile]

          # Generate certificate signing requests (CSR)
          conf_dir = File.dirname node[:heat][:ssl][:certfile]
          ssl_csr_file = "#{conf_dir}/signing_key.csr"
          ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{node[:fqdn]}\""
          `openssl req -new -key #{node[:heat][:ssl][:keyfile]} -out #{ssl_csr_file} -subj #{ssl_subject}`
          if $?.exitstatus != 0
            message = "SSL certificate signed requests generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          # Generate self-signed certificate with above CSR
          `openssl x509 -req -days 3650 -in #{ssl_csr_file} -signkey #{node[:heat][:ssl][:keyfile]} -out #{node[:heat][:ssl][:certfile]}`
          if $?.exitstatus != 0
            message = "SSL self-signed certificate generation failed"
            Chef::Log.fatal(message)
            raise message
          end

          File.delete ssl_csr_file  # Nobody should even try to use this
        end # unless files exist
      end # block
    end # ruby_block
  else # if generate_certs
    unless ::File.size? node[:heat][:ssl][:certfile]
      message = "Certificate \"#{node[:heat][:ssl][:certfile]}\" is not present or empty."
      Chef::Log.fatal(message)
      raise message
    end
    # we do not check for existence of keyfile, as the private key is allowed
    # to be in the certfile
  end # if generate_certs

  if node[:heat][:ssl][:cert_required] && !::File.size?(node[:heat][:ssl][:ca_certs])
    message = "Certificate CA \"#{node[:heat][:ssl][:ca_certs]}\" is not present or empty."
    Chef::Log.fatal(message)
    raise message
  end
end
