#
# Copyright 2016 SUSE Linux GmbH
# Copyright 2017 Fujitsu LIMITED
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

override[:monasca][:group] = "monasca"
override[:monasca][:user] = "monasca"

default[:monasca][:api][:bind_host] = "*"
default[:monasca][:api][:bind_port] = 8070

default[:monasca][:log_api][:bind_port] = 5607

default[:monasca][:kibana][:bind_port] = 5601
default[:monasca][:delegate_role] = "monasca-delegate"

# Database Settings
default[:monasca][:db_monapi][:password] = nil
default[:monasca][:db_monapi][:user] = "monapi"
# Don't change the database name. "mon" is hardcoded in the mysql mon.sql schema file
default[:monasca][:db_monapi][:database] = "mon"

# agent default service settings
default[:monasca][:agent]["user"] = "monasca-agent"
default[:monasca][:agent][:group] = "monasca"
default[:monasca][:agent]["log_dir"] = "/var/log/monasca-agent"
default[:monasca][:agent]["agent_service_name"] = "openstack-monasca-agent.target"

# log-agent default service settings
default[:monasca][:log_agent][:service_name] = "openstack-monasca-log-agent"
default[:monasca][:log_agent][:user] = "root"
default[:monasca][:log_agent][:group] = "root"

# HA attributes
default[:monasca][:ha][:enabled] = false
