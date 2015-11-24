name "nova"
maintainer "Crowbar project"
maintainer_email "crowbar@googlegroups.com"
license "Apache 2.0"
description "Installs/Configures nova"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "0.3"

depends "ceph"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "database"
depends "keystone"
depends "memcached"
depends "nagios"
depends "neutron"
depends "utils"

recommends "hyperv"
