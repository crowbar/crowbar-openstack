maintainer "User Unknown"
maintainer_email "Unknown@Sample.com"
license "Apache 2.0"
description "Installs/Configures Ceilometer"
long_description IO.read(File.join(File.dirname(__FILE__), "README.me"))
version "0.1"

depends "nagios"
depends "keystone"
depends "database"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "utils"

recommends "hyperv"
