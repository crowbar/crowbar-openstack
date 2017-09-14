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
        @current_resource.cert_required(@new_resource.cert_required)
        @current_resource.generate_ca(@new_resource.generate_ca)
        @current_resource.ca_certs(@new_resource.ca_certs)
        @current_resource
      end

      def action_setup
        if @current_resource.generate_certs
          require "fileutils"

          if @current_resource.generate_ca && !
            ::File.exist?(@current_resource.ca_certs)

            Chef::Log.info("Generating CA certificate...")

            package "openssl"

            dir = ::File.dirname(@current_resource.ca_certs)
            ::FileUtils.mkdir_p(dir) unless ::File.exist?(dir)

            # Generate CA key
            ca_key_file = "#{dir}/ca_key.pem"
            `openssl genrsa -out #{ca_key_file} 4096`
            if $?.exitstatus != 0
              message = "CA key generation failed"
              Chef::Log.fatal(message)
              raise message
            end

            ssl_subject = "\"/C=US/ST=Unset/L=Unset/O=Unset/CN=CA\""
            # generate CA certificate
            `openssl req -new -x509 -nodes -days 3650 -key #{ca_key_file} \
            -subj #{ssl_subject} -out #{@current_resource.ca_certs}`
            if $?.exitstatus != 0
              message = "CA certificate generation failed"
              Chef::Log.fatal(message)
              raise message
            end
          end
        end

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

            sign_by = "-signkey #{@current_resource.keyfile}"
            ca_dir = ::File.dirname(@current_resource.ca_certs)
            ca_key_file = "#{ca_dir}/ca_key.pem"
            if @current_resource.generate_ca
              sign_by = "-CA #{@current_resource.ca_certs} -CAkey #{ca_key_file} -set_serial 01"
            end

            # Generate self-signed certificate with above CSR
            `openssl x509 -req -days 3650 -in #{ssl_csr_file} #{sign_by} \
              -out #{@current_resource.certfile}`
            if $?.exitstatus != 0
              message = "SSL self-signed certificate generation failed"
              Chef::Log.fatal(message)
              raise message
            end

            ::File.delete ca_key_file if ::File.exist?(ca_key_file)
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
