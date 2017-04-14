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

default[:monasca][:db][:database] = "monasca"
default[:monasca][:db][:user] = "monasca"
default[:monasca][:db][:password] = nil # must be set by wrapper

override[:monasca][:group] = "monasca"
override[:monasca][:user] = "monasca"

default[:monasca][:api][:bind_host] = "*"

# metric-agent default service settings
default[:monasca][:metric_agent]["user"] = "monasca-agent"
default[:monasca][:metric_agent][:group] = "monasca"
default[:monasca][:metric_agent][:debug] = false
default[:monasca][:metric_agent]["log_dir"] = "/var/log/monasca-metric-agent"
default[:monasca][:metric_agent]["agent_service_name"] = "openstack-monasca-metric-agent"

# log-agent default service settings
default[:monasca][:log_agent][:service_name] = "openstack-monasca-log-agent"
default[:monasca][:log_agent][:user] = "root"
default[:monasca][:log_agent][:group] = "root"
