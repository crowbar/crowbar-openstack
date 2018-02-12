#
# Cookbook Name:: mysql
# Attributes:: server
#
# Copyright 2008-2009, Opscode, Inc.
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
# limitations under the License.
#

default[:database][:mysql][:bind_address]              = node[:ipaddress]
default[:database][:mysql][:tmpdir]                    = "/var/lib/mysqltmp"

if node[:database].key? "ec2"
  default[:database][:mysql][:ec2_path]                = "/mnt/mysql"
  default[:database][:mysql][:ebs_vol_dev]             = "/dev/sdi"
  default[:database][:mysql][:ebs_vol_size]            = 50
end

default[:database][:mysql][:tunable][:max_allowed_packet]       = "16M"
default[:database][:mysql][:tunable][:thread_cache_size]        = 8

# Ports to bind to when haproxy is used
default[:mysql][:ha][:ports][:admin_port] = 3306

# Default operation setting for the galera resource
# in pacemamker
default[:mysql][:ha][:op][:monitor][:interval] = "20s"
default[:mysql][:ha][:op][:monitor][:role]     = "Master"

# If needed we can enhance this to set the mariadb version
# depeding on "platform" and "platform_version". But currently
# this should be enough
default[:mysql][:mariadb][:version] = "10.2"
default[:mysql][:galera_packages] = [
  "galera-3-wsrep-provider",
  "mariadb-tools",
  "xtrabackup",
  "socat",
  "galera-python-clustercheck"
]

# newer version need an additional package on SLES
unless node[:mysql][:mariadb][:version] == "10.1"
  default[:mysql][:galera_packages] << "mariadb-galera"
end
