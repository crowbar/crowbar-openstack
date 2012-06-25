begin
  require 'pg'
rescue LoadError
  Chef::Log.info("Missing gem 'pg'")
end

module Opscode
  module Postgresql
    module Database
      def db(dbname=nil)
        @db ||= ::PGconn.connect( :host => new_resource.host,
                                  :port => 5432,
                                  :dbname => dbname,
                                  :user => new_resource.username,
                                  :password => new_resource.password)
        end
      def close
        @db.close rescue nil
        @db = nil
      end
    end
  end
end
