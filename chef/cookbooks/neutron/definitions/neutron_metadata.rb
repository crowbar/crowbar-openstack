# Copyright 2017, SUSE Linux Products GmBH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
define :neutron_metadata,
  use_cisco_apic_ml2_driver: false,
  neutron_network_ha: false,
  nova_compute_ha_enabled: false,
  neutron_node_object: nil do

  use_cisco_apic_ml2_driver = params[:use_cisco_apic_ml2_driver]
  neutron_network_ha = params[:neutron_network_ha]
  nova_compute_ha_enabled = params[:nova_compute_ha_enabled]
  neutron = params[:neutron_node_object] || node

  package node[:neutron][:platform][:metadata_agent_pkg]
  # TODO: nova should depend on neutron, but neutron also depends on nova
  # so we have to do something like this
  nova = node
  novas = Chef::Search::Query.new.search(:node, "roles:nova-controller")
  unless novas.empty? || novas[0].empty?
    # check for novas[0].empty? because the Query.new.search() returns [[], 0, 0]
    # instead of [] returned by the regular search helper.
    nova = novas[0][0]
    nova = node if nova.name == node.name
  end

  ha_enabled =
    if nova.fetch("nova", {}).fetch("ha", {})["enabled"].nil?
      false
    else
      nova[:nova][:ha][:enabled]
    end
  metadata_host = CrowbarHelper.get_host_for_admin_url(nova, ha_enabled)

  metadata_port = nova.fetch("nova", {}).fetch("ports", {})["metadata"] || 8775

  ssl_enabled =
    if nova.fetch("nova", {}).fetch("ssl", {})["enabled"].nil?
      false
    else
      nova[:nova][:ssl][:enabled]
    end
  metadata_protocol = ssl_enabled ? "https" : "http"

  ssl_insecure =
    if nova.fetch("nova", {}).fetch("ssl", {})["insecure"].nil?
      false
    else
      nova[:nova][:ssl][:insecure]
    end
  metadata_insecure = ssl_enabled && ssl_insecure

  metadata_proxy_shared_secret = nova.fetch("nova", {})["neutron_metadata_proxy_shared_secret"] || ""

  keystone_settings = KeystoneHelper.keystone_settings(neutron, @cookbook_name)

  # Empty the config file that is explicitly passed to the metadata agent, as
  # its content will prevail compared to config snippets (because the file is
  # explicitly passed as a config file, not loaded as part of the default files
  # to load).
  file "/etc/neutron/metadata_agent.ini" do
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    content "# Please use config file snippets in /etc/neutron/neutron-metadata-agent.conf.d/.\n" \
            "# See /etc/neutron/README.config for more details.\n"
  end

  template node[:neutron][:metadata_agent_config_file] do
    source "metadata_agent.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      debug: neutron[:neutron][:debug],
      keystone_settings: keystone_settings,
      auth_region: keystone_settings["endpoint_region"],
      neutron_insecure: neutron[:neutron][:ssl][:insecure],
      nova_metadata_host: metadata_host,
      nova_metadata_port: metadata_port,
      nova_metadata_protocol: metadata_protocol,
      nova_metadata_insecure: metadata_insecure,
      metadata_proxy_shared_secret: metadata_proxy_shared_secret
    )
  end

  unless use_cisco_apic_ml2_driver
    use_crowbar_pacemaker_service = \
      (neutron_network_ha && node[:pacemaker][:clone_stateless_services]) || nova_compute_ha_enabled

    enable_metadata = node.roles.include?("neutron-network") || !node[:neutron][:metadata][:force]

    # In case of Cisco ACI driver, supervisord takes care of starting up
    # the metadata agent.
    service node[:neutron][:platform][:metadata_agent_name] do
      if enable_metadata
        action [:enable, :start]
        subscribes :restart, resources(template: node[:neutron][:config_file])
        subscribes :restart, resources(template: node[:neutron][:metadata_agent_config_file])
        subscribes :restart, resources(file: "/etc/neutron/metadata_agent.ini")
      else
        action [:disable, :stop]
      end
      provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
      if nova_compute_ha_enabled
        supports no_crm_maintenance_mode: true
      else
        supports status: true, restart: true
      end
    end
    utils_systemd_service_restart node[:neutron][:platform][:metadata_agent_name] do
      if enable_metadata
        action use_crowbar_pacemaker_service ? :disable : :enable
      else
        action :disable
      end
    end
  end
end
