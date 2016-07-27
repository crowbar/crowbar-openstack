name "barbican"
maintainer "Crowbar project"
maintainer_email "crowbar@googlegroups.com"
license "Apache 2.0"
description "Installs/Configures Barbican"
long_description IO.read(File.join(File.dirname(__FILE__), "README.me"))
version "0.1"

depends "apache2"
depends "database"
depends "keystone"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "utils"
