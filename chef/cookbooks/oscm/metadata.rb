name "oscm"
maintainer "EST"
maintainer_email "arkadiusz.kowalczyk@ts.fujistu.com"
license "Apache 2.0"
description "Installs/Configures OSCM"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "0.1"

depends "database"
depends "keystone"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "utils"
