maintainer "Opscode, Inc."
maintainer_email "cookbooks@opscode.com"
license "Apache 2.0"
description "Installs and configures RabbitMQ server"
version "1.2.0"
recipe "rabbitmq", "Install and configure RabbitMQ"

depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "utils"
depends "nagios"
# depends           "apt"

%w{ubuntu debian}.each do |os|
  supports os
end

attribute "rabbitmq",
          display_name: "RabbitMQ",
          description: "Hash of RabbitMQ attributes",
          type: "hash"

attribute "rabbitmq/nodename",
          display_name: "RabbitMQ Erlang node name",
          description: "The Erlang node name for this server.",
          default: "node[:hostname]"

attribute "rabbitmq/address",
          display_name: "RabbitMQ server IP address",
          description: "IP address to bind."

attribute "rabbitmq/port",
          display_name: "RabbitMQ server port",
          description: "TCP port to bind."

attribute "rabbitmq/config",
          display_name: "RabbitMQ config file to load",
          description: "Path to the rabbitmq.config file, if any."

attribute "rabbitmq/logdir",
          display_name: "RabbitMQ log directory",
          description: "Path to the directory for log files."

attribute "rabbitmq/mnesiadir",
          display_name: "RabbitMQ Mnesia database directory",
          description: "Path to the directory for Mnesia database files."

attribute "rabbitmq/erlang_cookie",
          display_name: "RabbitMQ Erlang cookie",
          description: "Access cookie for clustering nodes.  There is no default."

