#
# Cookbook Name:: trove
# Attributes:: default
#
# Copyright 2014, SUSE Linux Products GmbH
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

default[:trove][:debug] = false

default[:trove][:user] = "trove"
default[:trove][:group] = "trove"
default[:trove][:api][:config_file] = "/etc/trove/trove-api.conf.d/100-trove-api.conf"
default[:trove][:conductor][:config_file] = \
  "/etc/trove/trove-conductor.conf.d/100-trove-conductor.conf"
default[:trove][:taskmanager][:config_file] = \
  "/etc/trove/trove-taskmanager.conf.d/100-trove-taskmanager.conf"

default[:trove][:volume_support] = false

default[:trove][:service_user] = "trove"
default[:trove][:service_password] = "trove"

default[:trove][:db][:password] = nil
default[:trove][:db][:database] = "trove"
default[:trove][:db][:user] = "trove"
