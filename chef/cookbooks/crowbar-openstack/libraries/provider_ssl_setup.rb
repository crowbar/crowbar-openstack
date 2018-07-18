require "chef/provider"

class Chef
  class Provider
    class SslSetup < Chef::Provider
      def load_current_resource
        @current_resource = Chef::Resource::SslSetup.new(@new_resource.name)
        @current_resource.generate_certs(@new_resource.generate_certs)
        @current_resource.certfile(@new_resource.certfile)
        @current_resource.keyfile(@new_resource.keyfile)
        @current_resource.group(@new_resource.group)
        @current_resource.fqdn(@new_resource.fqdn)
        @current_resource.alt_names(@new_resource.alt_names)
        @current_resource.cert_required(@new_resource.cert_required)
        @current_resource.ca_certs(@new_resource.ca_certs)
        @current_resource
      end

      def action_setup
        if @current_resource.generate_certs
          unless ::File.exist?(@current_resource.certfile) \
            && ::File.exist?(@current_resource.keyfile)

            require "fileutils"

            Chef::Log.info("Generating SSL certificate...")

            package "openssl"

            [@current_resource.certfile, @current_resource.keyfile].each do |k|
              dir = ::File.dirname(k)
              ::FileUtils.mkdir_p(dir) unless ::File.exist?(dir)
            end

            # Generate private key
            `openssl genrsa -out #{@current_resource.keyfile} 4096`
            if $?.exitstatus != 0
              message = "SSL private key generation failed"
              Chef::Log.fatal(message)
              raise message
            end
            ::FileUtils.chown "root", @current_resource.group, @current_resource.keyfile
            ::FileUtils.chmod 0640, @current_resource.keyfile

            # Generate certificate signing requests (CSR)
            conf_dir = ::File.dirname @current_resource.certfile
            ssl_csr_file = "#{conf_dir}/signing_key.csr"
            ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=#{@current_resource.fqdn}\""
            `openssl req -new -key #{@current_resource.keyfile} \
            -out #{ssl_csr_file} -subj #{ssl_subject}`
            if $?.exitstatus != 0
              message = "SSL certificate signed requests generation failed"
              Chef::Log.fatal(message)
              raise message
            end

            # Generate x509v3 extensions (restricting CA usage, set alt names)
            ssl_x509v3_ext = "#{conf_dir}/signing_key.conf"
            cfg = ::File.new(ssl_x509v3_ext, "w")
            cfg.write(%{
[v3_req]
subjectKeyIdentifier = hash
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature, nonRepudiation})
            cfg.write(%{
subjectAltName       = #{@current_resource.alt_names.join ', '}
                      }) if @current_resource.alt_names.any?
            cfg.close

            # Generate self-signed certificate with above CSR
            `openssl x509 -req -days 3650 -in #{ssl_csr_file} \
              -extfile #{ssl_x509v3_ext} -extensions v3_req \
              -signkey #{@current_resource.keyfile} -out #{@current_resource.certfile}`
            if $?.exitstatus != 0
              message = "SSL self-signed certificate generation failed"
              Chef::Log.fatal(message)
              raise message
            end

            ::File.delete ssl_x509v3_ext # No longer needed
            ::File.delete ssl_csr_file # Nobody should even try to use this
          end # unless files exist
        else # if generate_certs
          unless ::File.size? @current_resource.certfile
            message = "Certificate '#{@current_resource.certfile}' is not present or empty."
            Chef::Log.fatal(message)
            raise message
          end
          # We do not check for existence of keyfile, as the private key is
          # allowed to be in the certfile
        end # if generate_certs

        if @current_resource.cert_required && ! ::File.size?(@current_resource.ca_certs)
          message = "Certificate CA '#{@current_resource.ca_certs}' is not present or empty."
          Chef::Log.fatal(message)
          raise message
        end
      end
    end
  end
end
