actions :create, :delete
default_action :create

attribute :bind_host, kind_of: String, default: "localhost"
attribute :bind_port, kind_of: Integer, default: 80
attribute :daemon_process, kind_of: String
attribute :user, kind_of: String
attribute :group, kind_of: String, default: nil
attribute :processes, kind_of: Integer, default: 3
attribute :threads, kind_of: Integer, default: 10
attribute :process_group, kind_of: String, default: nil
attribute :script_alias, kind_of: String, default: nil
attribute :directory, kind_of: String, default: nil

attribute :pass_authorization, kind_of: [TrueClass, FalseClass], default: false
attribute :limit_request_body, kind_of: Integer, default: nil

attribute :ssl_enable, kind_of: [TrueClass, FalseClass], default: false
attribute :ssl_certfile, kind_of: String, default: nil
attribute :ssl_keyfile, kind_of: String, default: nil
attribute :ssl_cacert, kind_of: String, default: nil

attribute :timeout, kind_of: Integer, default: nil

attribute :access_log, kind_of: String, default: nil
attribute :error_log, kind_of: String, default: nil

attr_accessor :exists
