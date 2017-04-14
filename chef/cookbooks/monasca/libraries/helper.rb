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

  def self.log_api_public_url(node)
    host = monasca_public_host(node)
    # SSL is not supported at this moment
    # protocol = node[:monasca][:log_api][:ssl] ? "https" : "http"
    protocol = "http"
    port = 5607
    "#{protocol}://#{host}:#{port}/v3.0"
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
