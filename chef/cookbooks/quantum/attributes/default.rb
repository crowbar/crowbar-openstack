
# Copyright (c) 2011 Dell Inc.
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

default[:quantum][:debug] = true
default[:quantum][:verbose] = true
default[:quantum][:networking_mode] = "local"

default[:quantum][:db][:database] = "quantum"
default[:quantum][:db][:user] = "quantum"
default[:quantum][:db][:password] = "" # Set by Recipe
default[:quantum][:db][:ovs_database] = "ovs"
default[:quantum][:db][:ovs_user] = "ovs"
default[:quantum][:db][:ovs_password] = "" # Set by Recipe
default[:quantum][:network][:fixed_router] = "127.0.0.1" # Set by Recipe
default[:quantum][:network][:private_networks] = [] # Set by Recipe
# Default range for GRE tunnels
default[:quantum][:network][:gre_start] = 1
default[:quantum][:network][:gre_stop] = 1000


default[:quantum][:api][:service_port] = "9696"
default[:quantum][:api][:service_host] = "0.0.0.0"

default[:quantum][:sql][:idle_timeout] = 30
default[:quantum][:sql][:min_pool_size] = 5
default[:quantum][:sql][:max_pool_size] = 10
default[:quantum][:sql][:pool_timeout] = 200

default[:quantum][:quantum_server] = false
