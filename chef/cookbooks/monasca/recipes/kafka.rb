#
# Cookbook Name:: monasca
# Recipe:: kafka
#
# Copyright 2018, SUSE Linux GmbH.
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

["kafka", "python-kafka-python"].each do |p|
  package p do
    action :install
  end
end

monasca_servers = search(:node, "roles:monasca-server")
monasca_hosts = MonascaHelper.monasca_hosts(monasca_servers).sort!

directory node[:monasca][:kafka][:data_dir] do
    mode "0755"
    owner "kafka"
    group "kafka"
    recursive true
  end

template "/etc/kafka/log4j.properties" do
  source "kafka-log4j.properties.erb"
  owner "kafka"
  group "kafka"
  mode "0640"
  variables(
    kafka_log_level: node[:monasca][:debug] ? "DEBUG" : "WARN"
  )
  notifies :restart, "service[kafka]"
end

template "/etc/kafka/server.properties" do
  source "kafka-server.properties.erb"
  owner "kafka"
  group "kafka"
  mode "0640"
  variables(
    # FIXME: 0 works because we currently allow only a single kafka server
    kafka_broker_id: 0,
    kafka_port: node[:monasca][:kafka][:port],
    kafka_listen_address: node[:monasca][:kafka][:listen_address],
    kafka_num_network_threads: node[:monasca][:kafka][:num_network_threads],
    kafka_num_io_threads: node[:monasca][:kafka][:num_io_threads],
    kafka_socket_send_buffer_bytes: node[:monasca][:kafka][:socket_send_buffer_bytes],
    kafka_socket_receive_buffer_bytes: node[:monasca][:kafka][:socket_receive_buffer_bytes],
    kafka_socket_request_max_bytes: node[:monasca][:kafka][:socket_request_max_bytes],
    kafka_connections_max_idle_ms: node[:monasca][:kafka][:connections_max_idle_ms],
    kafka_data_dir: node[:monasca][:kafka][:data_dir],
    kafka_auto_create_topics: node[:monasca][:kafka][:auto_create_topics],
    kafka_num_partitions: node[:monasca][:kafka][:num_partitions],
    kafka_log_flush_interval_messages: node[:monasca][:kafka][:log_flush_interval_messages],
    kafka_log_flush_interval_ms: node[:monasca][:kafka][:log_flush_interval_ms],
    kafka_log_retention_hours: node[:monasca][:kafka][:log_retention_hours],
    kafka_log_retention_bytes: node[:monasca][:kafka][:log_retention_bytes],
    kafka_log_segment_bytes: node[:monasca][:kafka][:log_segment_bytes],
    kafka_replica_fetch_max_bytes: node[:monasca][:kafka][:replica_fetch_max_bytes],
    kafka_message_max_bytes: node[:monasca][:kafka][:message_max_bytes],
    kafka_zookeeper_hosts: monasca_hosts,
    kafka_zookeeper_connection_timeout_ms: node[:monasca][:kafka][:zookeeper_connection_timeout_ms]
  )
  notifies :restart, "service[kafka]"
end

service "kafka" do
  supports status: true, restart: true, start: true, stop: true
  action [:enable, :start]
end

# create topics
# TODO: handle the case where the replicas or partitions attributes change.
# then the topic needs to be updated
node["monasca"]["kafka"]["topics"].each do |t|
  cmd = "/usr/bin/kafka-topics.sh --create --zookeeper #{monasca_hosts.join(',')}"
  cmd << " --replication-factor #{t['replicas']}"
  cmd << " --partitions #{t['partitions']}"
  if t.has_key?("config_options")
    t["config_options"].each do |co|
      cmd << " --config #{co}"
    end
  end
  cmd << " --topic #{t['name']}"
  execute "Create kafka topic #{t['name']}" do
    command cmd
    not_if "/usr/bin/kafka-topics.sh --list --zookeeper #{monasca_hosts.join(',')}|grep #{t['name']}"
  end
end
