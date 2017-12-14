# Copyright 2016 SUSE Linux GmbH
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

module MonascaUiHelper
  def self.monasca_public_host(node)
    ha_enabled = node[:monasca][:ha][:enabled]
    ssl_enabled = node[:monasca][:api][:ssl]
    CrowbarHelper.get_host_for_public_url(node, ssl_enabled, ha_enabled)
  end

  def self.monasca_admin_host(node)
    CrowbarHelper.get_host_for_admin_url(node, node[:monasca][:ha][:enabled])
  end

  def self.api_public_url(node)
    host = monasca_public_host(node)
    # SSL is not supported at this moment
    # protocol = node[:monasca][:api][:ssl] ? "https" : "http"
    protocol = "http"
    port = node[:monasca][:api][:bind_port]
    "#{protocol}://#{host}:#{port}/v2.0"
  end

  def self.dashboard_ip(node)
    ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address

    if node[:horizon][:ha][:enabled] && !@cluster_admin_ip
      ip = CrowbarPacemakerHelper.cluster_vip(node, "public")
    end

    ip
  end

  def self.dashboard_local_url(node)
    public_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "public").address
    admin_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address

    ha_enabled = node[:horizon][:ha][:enabled]
    ssl_enabled = node[:horizon][:apache][:ssl]

    protocol = "http"
    protocol = "https" if ssl_enabled

    if ha_enabled
      port = node[:horizon][:ha][:ports][:plain]
      port = node[:horizon][:ha][:ports][:ssl] if ssl_enabled
      return "#{protocol}://#{admin_ip}:#{port}"
    end

    "#{protocol}://#{public_ip}"
  end

  def self.dashboard_public_url(node)
    protocol = "http"
    protocol = "https" if node[:horizon][:apache][:ssl]

    "#{protocol}://#{dashboard_ip(node)}"
  end

  def self.grafana_service_url(node)
    "http://#{monasca_public_host(node)}:3000"
  end
end
