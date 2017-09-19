maintainer "User Unknown"
maintainer_email "crowbar@dell.com"
license "Apache 2.0"
description "Installs/Configures Heat"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "0.1"

depends "nagios"
depends "keystone"
depends "memcached"
depends "database"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "utils"
