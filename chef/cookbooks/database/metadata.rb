maintainer       "Opscode, Inc."
maintainer_email "cookbooks@opscode.com"
license          "Apache 2.0"
description      "Sets up the database master or slave"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.1.4"

recipe "database", "Empty placeholder"

depends "mysql"
depends "postgresql"
depends "crowbar-pacemaker"

%w{ debian ubuntu centos suse fedora redhat scientific }.each do |os|
  supports os
end
