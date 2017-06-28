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
    # SSL is not supported at this moment
    # protocol = node[:monasca][:api][:ssl] ? "https" : "http"
    protocol = "http"
    port = node[:monasca][:api][:bind_port]
    "#{protocol}://#{host}:#{port}/v2.0"
  end

  def self.api_admin_url(node)
    host = monasca_admin_host(node)
    # SSL is not supported at this moment
    # protocol = node[:monasca][:api][:ssl] ? "https" : "http"
    protocol = "http"
    port = node[:monasca][:api][:bind_port]
    "#{protocol}://#{host}:#{port}/v2.0"
  end

  def self.api_internal_url(node)
    host = get_host_for_monitoring_url(node)
    # SSL is not supported at this moment
    # protocol = node[:monasca][:api][:ssl] ? "https" : "http"
    protocol = "http"
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
    # SSL is not supported at this moment
    # protocol = node[:monasca][:log_api][:ssl] ? "https" : "http"
    protocol = "http"
    port = node[:monasca][:log_api][:bind_port]
    "#{protocol}://#{host}:#{port}/#{version}"
  end

  def self.log_api_admin_url(node, version = "v3.0")
    host = monasca_admin_host(node)
    # SSL is not supported at this moment
    # protocol = node[:monasca][:log_api][:ssl] ? "https" : "http"
    protocol = "http"
    port = node[:monasca][:log_api][:bind_port]
    "#{protocol}://#{host}:#{port}/#{version}"
  end

  def self.log_api_internal_url(node, version = "v3.0")
    host = get_host_for_monitoring_url(node)
    # SSL is not supported at this moment
    # protocol = node[:monasca][:log_api][:ssl] ? "https" : "http"
    protocol = "http"
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
end
