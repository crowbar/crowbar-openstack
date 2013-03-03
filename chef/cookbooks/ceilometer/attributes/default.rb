# Copyright 2012, Dell Inc., Inc.
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

default[:ceilometer][:user] = "ceilometer"

default[:ceilometer][:debug] = true
default[:ceilometer][:verbose] = true

default[:ceilometer][:db][:database] = "ceilometer"
default[:ceilometer][:db][:user] = "ceilometer"
default[:ceilometer][:db][:password] = "" # Set by Recipe

default[:ceilometer][:api][:port] = "8777"
default[:ceilometer][:api][:host] = "0.0.0.0"


default[:ceilometer][:sql][:idle_timeout] = 30
default[:ceilometer][:sql][:min_pool_size] = 5
default[:ceilometer][:sql][:max_pool_size] = 10
default[:ceilometer][:sql][:pool_timeout] = 200

