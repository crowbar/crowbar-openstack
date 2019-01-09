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

default[:monasca][:db_grafana][:password] = nil
default[:monasca][:db_grafana][:user] = "grafana"
default[:monasca][:db_grafana][:database] = "grafana"

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

# zookeeper
default[:monasca][:zookeeper][:data_dir] = "/var/lib/zookeeper/data"
default[:monasca][:zookeeper][:client_port_address] = "0.0.0.0"
default[:monasca][:zookeeper][:client_port] = 2181

# kafka
default[:monasca][:kafka][:listen_address] = nil
default[:monasca][:kafka][:port] = 9092
default[:monasca][:kafka][:num_network_threads] = 2
default[:monasca][:kafka][:num_io_threads] = 2
default[:monasca][:kafka][:socket_send_buffer_bytes] = 1048576
default[:monasca][:kafka][:socket_receive_buffer_bytes] = 1048576
default[:monasca][:kafka][:socket_request_max_bytes] = 104857600
default[:monasca][:kafka][:connections_max_idle_ms] = 86400000
default[:monasca][:kafka][:data_dir] = "/var/kafka"
default[:monasca][:kafka][:auto_create_topics] = "false"
default[:monasca][:kafka][:num_partitions] = 2
default[:monasca][:kafka][:log_flush_interval_messages] = 10000
default[:monasca][:kafka][:log_flush_interval_ms] = 1000
default[:monasca][:kafka][:log_retention_hours] = 24
default[:monasca][:kafka][:log_retention_bytes] = 21474836480
default[:monasca][:kafka][:log_segment_bytes] = 104857600
default[:monasca][:kafka][:replica_fetch_max_bytes] = 1048576
default[:monasca][:kafka][:message_max_bytes] = 1000012
default[:monasca][:kafka][:zookeeper_connection_timeout_ms] = 1000000

# elasticsearch
default[:monasca][:elasticsearch][:cluster_name] = "elasticsearch"
default[:monasca][:elasticsearch][:is_master_node] = "true"
default[:monasca][:elasticsearch][:is_data_node] = "true"
default[:monasca][:elasticsearch][:data_dirs] = ["/var/data/elasticsearch"]
default[:monasca][:elasticsearch][:log_dir] = "/var/log/elasticsearch"
default[:monasca][:elasticsearch][:repo_dirs] = []
default[:monasca][:elasticsearch][:bootstrap_memory_lock] = "true"
