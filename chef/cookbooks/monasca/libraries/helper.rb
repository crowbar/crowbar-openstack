#
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
# limitations under the License.

require 'json'
require 'open3'

module MonascaHelper
  def self.monasca_public_host(node)
    ha_enabled = node[:monasca][:ha][:enabled]
    ssl_enabled = node[:monasca][:api][:ssl]
    CrowbarHelper.get_host_for_public_url(node, ssl_enabled, ha_enabled)
  end

  def self.monasca_admin_host(node)
    ha_enabled = node[:monasca][:ha][:enabled]
    CrowbarHelper.get_host_for_admin_url(node, ha_enabled)
  end

  def self.api_public_url(node)
    host = monasca_public_host(node)
    protocol = node[:monasca][:api][:protocol]
    port = node[:monasca][:api][:bind_port]
    "#{protocol}://#{host}:#{port}/v2.0"
  end

  def self.api_admin_url(node)
    host = monasca_admin_host(node)
    protocol = node[:monasca][:api][:protocol]
    port = node[:monasca][:api][:bind_port]
    "#{protocol}://#{host}:#{port}/v2.0"
  end

  def self.api_internal_url(node)
    host = get_host_for_monitoring_url(node)
    protocol = node[:monasca][:api][:protocol]
    port = node[:monasca][:api][:bind_port]
    "#{protocol}://#{host}:#{port}/v2.0"
  end

  # api_network_url returns url to monasca-api based on check if custom
  # network for api is set, if not it will returns public url for api.
  def self.api_network_url(node)
    monasca_api_url = if node[:monasca][:api][:url].nil? ||
        node[:monasca][:api][:url].empty?
      api_public_url(node)
    else
      node[:monasca][:api][:url]
    end
    return monasca_api_url
  end

  def self.log_api_public_url(node, version = "v3.0")
    host = monasca_public_host(node)
    protocol = node[:monasca][:api][:protocol]
    port = node[:monasca][:log_api][:bind_port]
    "#{protocol}://#{host}:#{port}/#{version}"
  end

  def self.log_api_admin_url(node, version = "v3.0")
    host = monasca_admin_host(node)
    protocol = node[:monasca][:api][:protocol]
    port = node[:monasca][:log_api][:bind_port]
    "#{protocol}://#{host}:#{port}/#{version}"
  end

  def self.log_api_internal_url(node, version = "v3.0")
    host = get_host_for_monitoring_url(node)
    protocol = node[:monasca][:api][:protocol]
    port = node[:monasca][:log_api][:bind_port]
    "#{protocol}://#{host}:#{port}/#{version}"
  end

  def self.logs_search_public_url(node)
    host = monasca_public_host(node)
    # SSL is not supported at this moment
    protocol = "http"
    port = node[:monasca][:kibana][:bind_port]
    "#{protocol}://#{host}:#{port}/"
  end

  def self.logs_search_admin_url(node)
    host = monasca_admin_host(node)
    # SSL is not supported at this moment
    protocol = "http"
    port = node[:monasca][:kibana][:bind_port]
    "#{protocol}://#{host}:#{port}/"
  end

  def self.logs_search_internal_url(node)
    host = get_host_for_monitoring_url(node)
    # SSL is not supported at this moment
    protocol = "http"
    port = node[:monasca][:kibana][:bind_port]
    "#{protocol}://#{host}:#{port}/"
  end

  # log_api_network_url returns url to monasca-log-api based on check if custom
  # network for log-api is set, if not it will returns public url for log-api.
  def self.log_api_network_url(node)
    monasca_log_api_url = if node[:monasca][:log_api][:url].nil? ||
        node[:monasca][:log_api][:url].empty?
      log_api_public_url(node)
    else
      node[:monasca][:log_api][:url]
    end
    return monasca_log_api_url
  end

  # Returns a log API health check URL for use by a Monasca agent's http_check
  # plugin
  def self.log_api_healthcheck_url(node)
    my_net = node[:monasca][:network]
    port = node[:monasca][:log_api][:bind_port]
    listen_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(
      node, my_net).address

    "http://#{listen_ip}:#{port}/healthcheck"
  end

  def self.monasca_hosts(nodes)
    hosts = []
    nodes.each do |n|
      hosts.push(CrowbarHelper.get_host_for_admin_url(n))
    end
    hosts
  end

  def self.get_host_for_monitoring_url(node)
    Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "monitoring").address
  end

  def self.call(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    raise "Can not execute '#{cmd}': #{stderr}" unless status.success?
    stdout
  end
end


module InfluxDBHelper
  def self.get_databases(**options)
    cmd = base_cmd(**options)
    cmd << " -execute 'SHOW DATABASES' -format json"
    dbs = MonascaHelper.call(cmd)
    dbs_json = JSON.parse(dbs)
    unless dbs_json['results'][0]['series'][0].has_key?("values")
      return []
    end
    dbs_json['results'][0]['series'][0]['values'].flatten
  end

  def self.create_database(db_name, **options)
    dbs_available = InfluxDBHelper.get_databases(**options)
    unless dbs_available.include?(db_name)
      cmd = base_cmd(**options)
      cmd << " -execute 'CREATE DATABASE #{db_name}'"
      MonascaHelper.call(cmd)
    end
  end

  def self.get_users(db_name, **options)
    cmd = base_cmd(**options)
    cmd << " -database #{db_name}"
    cmd << " -execute 'SHOW USERS' -format json"
    users = MonascaHelper.call(cmd)
    users_json = JSON.parse(users)
    unless users_json['results'][0]['series'][0].has_key?("values")
      return []
    end
    users = []
    users_json['results'][0]['series'][0]['values'].each do |user, admin|
      users << user
    end
    users
  end

  def self.create_user(new_username, new_password, db_name, **options)
    users_available = InfluxDBHelper.get_users(db_name, **options)
    unless users_available.include?(new_username)
      cmd = base_cmd(**options)
      cmd << " -database #{db_name}"
      cmd << " -execute \"CREATE USER #{new_username} WITH PASSWORD '#{new_password}'\""
      MonascaHelper.call(cmd)
    end
  end

  def self.get_retention_policies(db_name, **options)
    cmd = base_cmd(**options)
    cmd << " -database #{db_name}"
    cmd << " -execute 'SHOW RETENTION POLICIES ON #{db_name}' -format json"
    rps_val = MonascaHelper.call(cmd)
    rps_json = JSON.parse(rps_val)
    unless rps_json['results'][0]['series'][0].has_key?("values")
      return []
    end
    rps = []
    rps_json['results'][0]['series'][0]['values'].each do |name, duration, shard_group_duration, replicas, default|
      rps << {
        "name" => name,
        "duration" => duration,
        "shard_group_duration" => shard_group_duration,
        "replicas" => replicas,
        "default" => default
      }
    end
    rps
  end

  def self.create_retention_policy(db_name, policy_name, duration, replicas,
    shard_group_duration: nil, default: nil, **options)

    cmd_create = base_cmd(**options)
    cmd_create << " -database #{db_name}"
    cmd_create << " -execute 'CREATE RETENTION POLICY #{policy_name} ON #{db_name}"
    cmd_create << " DURATION #{duration}"
    cmd_create << " REPLICATION #{replicas}"
    unless shard_group_duration.nil?
      cmd_create << " SHARD DURATION #{shard_group_duration}"
    end
    unless default.nil?
      cmd_create << " #{default}"
    end
    cmd_create << "'"
    MonascaHelper.call(cmd_create)
  end

  def self.set_retention_policy(db_name, policy_name, duration, replicas,
    shard_group_duration: nil, default: nil,
    **options)
    rps_available = InfluxDBHelper.get_retention_policies(db_name, **options)
    rp = rps_available.find { |rp| rp['name'] == policy_name }
    if rp
      # update policy
      needs_update = false
      cmd_update = base_cmd(**options)
      cmd_update << " -database #{db_name}"
      cmd_update << " -execute 'ALTER RETENTION POLICY #{policy_name} ON #{db_name}"
      if rp['duration'] != duration
        cmd_update << " DURATION #{duration}"
        needs_update = true
      end
      if rp['replicas'] != replicas
        cmd_update << " REPLICATION #{replicas}"
        needs_update = true
      end
      if shard_group_duration && rp['shard_group_durating'] != shard_group_duration
        cmd_update << " SHARD DURATION #{shard_group_duration}"
        needs_update = true
      end
      cmd_update << "'"
      if needs_update
        MonascaHelper.call(cmd_update)
      end
    else
      # create policy
      InfluxDBHelper.create_retention_policy(db_name, policy_name, duration, replicas,
                                             shard_group_duration: shard_group_duration,
                                             default: default, **options)
    end
  end

  private_class_method def self.base_cmd(**options)
    base_cmd = "/usr/bin/influx"
    if options.fetch(:influx_host, false)
      base_cmd << " -host #{options[:influx_host]}"
    end
    if options.fetch(:influx_port, false)
      base_cmd << " -port #{options[:influx_port]}"
    end
    if options.fetch(:influx_username, false)
      base_cmd << " -username #{options[:influx_username]}"
    end
    if options.fetch(:influx_password, false)
      base_cmd << " -password #{options[:influx_password]}"
    end
    base_cmd
    end
end
