name "openstack-database"
maintainer "SUSE Linux GmbH"
maintainer_email "crowbar@dell.com"
license "Apache 2.0"
description "Installs/Configures trove"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "9.0.1"
recipe "openstack-database::api", "Installs API service"
recipe "openstack-database::taskmanager", "Installs TaskManager service"

depends "openstack-common", "~> 9.6"

supports "suse"
