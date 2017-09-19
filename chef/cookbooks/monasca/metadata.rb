name "monasca"
maintainer "Crowbar project"
maintainer_email "crowbar@googlegroups.com"
license "Apache 2.0"
description "Installs/Configures Monasca"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "0.1"

depends "database"
depends "keystone"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "utils"
