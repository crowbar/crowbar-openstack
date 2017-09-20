require "chef/resource"

class Chef
  class Resource
    class SslSetup < Chef::Resource
      def initialize(name, run_context = nil)
        super

        @resource_name = :ssl_setup
        @provider = Chef::Provider::SslSetup
        @action = :setup
        @allowed_actions = [:setup]

        # Define resource defaults
        @generate_certs = false
        @certfile = ""
        @keyfile = ""
        @group = ""
        @fqdn = ""
        @cert_required = false
        @generate_ca = false
        @ca_certs = ""
      end

      def generate_certs(arg = nil)
        set_or_return(:generate_certs, arg, kind_of: [TrueClass, FalseClass])
      end

      def certfile(arg = nil)
        set_or_return(:certfile, arg, kind_of: String)
      end

      def keyfile(arg = nil)
        set_or_return(:keyfile, arg, kind_of: String)
      end

      def group(arg = nil)
        set_or_return(:group, arg, kind_of: String)
      end

      def fqdn(arg = nil)
        set_or_return(:fqdn, arg, kind_of: String)
      end

      def cert_required(arg = nil)
        set_or_return(:cert_required, arg, kind_of: [TrueClass, FalseClass])
      end

      def generate_ca(arg = nil)
        set_or_return(:generate_ca, arg, kind_of: [TrueClass, FalseClass])
      end

      def ca_certs(arg = nil)
        set_or_return(:ca_certs, arg, kind_of: String)
      end
    end
  end
end
