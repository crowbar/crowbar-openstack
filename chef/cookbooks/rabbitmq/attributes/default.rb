#
# Cookbook Name:: rabbitmq
# Attributes:: default
#
# Copyright 2008-2011, Opscode, Inc.
# Copyright 2011-2013, Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# RabbitMQ Settings
#
default[:rabbitmq][:user] = "nova"
default[:rabbitmq][:vhost] = "/nova"
default[:rabbitmq][:rabbitmq_user] = "rabbitmq"
default[:rabbitmq][:rabbitmq_group] = "rabbitmq"

default[:rabbitmq][:nodename]  = "rabbit@#{node[:hostname]}"
# This is the address for internal usage
default[:rabbitmq][:address] = nil
# These are all the addresses, possibly including public one
default[:rabbitmq][:addresses] = []
default[:rabbitmq][:port]  = 5672
default[:rabbitmq][:management_port] = 15672
default[:rabbitmq][:management_address] = nil
default[:rabbitmq][:configfile] = nil
default[:rabbitmq][:logdir] = nil
default[:rabbitmq][:mnesiadir] = nil

default[:rabbitmq][:cluster] = false
default[:rabbitmq][:clustername] = "rabbit@#{node[:hostname]}"

# ha
default[:rabbitmq][:ha][:enabled] = false
default[:rabbitmq][:ha][:storage][:mode] = nil
default[:rabbitmq][:ha][:op][:start][:timeout] = "300s"
default[:rabbitmq][:ha][:op][:promote][:timeout] = "180s"
default[:rabbitmq][:ha][:op][:monitor][:interval] = "10s"
default[:rabbitmq][:ha][:clustered_op][:start][:timeout] = "360s"
default[:rabbitmq][:ha][:clustered_op][:stop][:timeout] = "120s"
default[:rabbitmq][:ha][:clustered_op][:promote][:timeout] = "120s"
default[:rabbitmq][:ha][:clustered_op][:demote][:timeout] = "120s"
default[:rabbitmq][:ha][:clustered_op][:notify][:timeout] = "180s"
default[:rabbitmq][:ha][:clustered_op][:monitor] = [
  { interval: "30s" }, { interval: "27s", role: "Master" }
]

default[:rabbitmq][:hipe_compile] = false
default[:rabbitmq][:ha][:clustered_rmq_features] = false
case node[:platform_family]
when "suse"
  if node[:platform] != "suse" || node[:platform_version].to_f > 12.2
    default[:rabbitmq][:hipe_compile] = true
    default[:rabbitmq][:ha][:clustered_rmq_features] = true
  end
end

# create empty users list as it is expected by some recipes
default[:rabbitmq][:users] = []
