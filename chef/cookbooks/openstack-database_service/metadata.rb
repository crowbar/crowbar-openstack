name             'openstack-database-service'
maintainer       'SUSE Linux GmbH'
maintainer_email 'crowbar@dell.com'
license          "Apache 2.0"
description      'Installs/Configures trove'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '9.0.0'
recipe           "openstack-database-service::identity_registration", "Registers Trove endpoints and service with Keystone"
recipe           "openstack-database-service::api", "Installs API service"
recipe           "openstack-database-service::conductor", "Installs Conductor service"
recipe           "openstack-database-service::taskmanager", "Installs TaskManager service"
recipe           "openstack-database-service::guestagent", "Installs GuestAgent service"

depends          'openstack-common', '~> 8.0'
depends          'openstack-identity', '~> 8.0'

supports "suse"
