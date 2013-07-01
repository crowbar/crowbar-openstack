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

default[:rabbitmq][:nodename]  = node[:hostname]
default[:rabbitmq][:address]  = nil
default[:rabbitmq][:port]  = 5672
default[:rabbitmq][:mochiweb_port] = 55672
default[:rabbitmq][:configfile] = nil
default[:rabbitmq][:logdir] = nil
default[:rabbitmq][:mnesiadir] = nil
#clustering
default[:rabbitmq][:cluster] = "no"
default[:rabbitmq][:cluster_config] = "/etc/rabbitmq/rabbitmq_cluster.config"
default[:rabbitmq][:cluster_disk_nodes] = []
