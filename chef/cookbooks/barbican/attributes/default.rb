#
# Copyright 2016 SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitation.

default[:barbican][:db][:database] = "barbican"
default[:barbican][:db][:user] = "barbican"
default[:barbican][:db][:password] = nil # must be set by wrapper
default[:barbican][:kek] = nil # must be set by wrapper

override[:barbican][:group] = "barbican"
override[:barbican][:user] = "barbican"

default[:barbican][:debug] = false
default[:barbican][:api][:bind_host] = "*"
default[:barbican][:api][:ssl] = false

default[:barbican][:logfile] = "/var/log/barbican/barbican-api.log"

# HA attributes
default[:barbican][:ha][:enabled] = false

# Ports to bind to when haproxy is used for the real ports
default[:barbican][:ha][:ports][:api] = 5621

# pacemaker definitions
default[:barbican][:ha][:api][:op][:monitor][:interval] = "10s"
default[:barbican][:ha][:worker][:op][:monitor][:interval] = "10s"
default[:barbican][:ha][:keystone_listener][:op][:monitor][:interval] = "10s"
default[:barbican][:ha][:api][:agent] = "lsb:openstack-barbican-api"
default[:barbican][:ha][:worker][:agent] = "lsb:openstack-barbican-worker"
default[:barbican][:ha][:keystone_listener][:agent] = "lsb:openstack-barbican-keystone-listener"
