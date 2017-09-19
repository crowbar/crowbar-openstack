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

  nova_metadata_settings = {}
  # TODO: nova should depend on neutron, but neutron also depends on nova
  # so we have to do something like this
  nova = node_search_with_cache("roles:nova-controller").first
  unless nova.nil?
    # If ec2-api is also enabled, the ec2 api metadata service needs to be targetted
    # instead of the nova metadata service
    ec2api = node_search_with_cache("roles:ec2-api").first
    # These if branches should be easy to merge when ec2-api is a
    # full fledged barclamp
    if ec2api.nil?
      ha_enabled = nova[:nova][:ha][:enabled]
      nova_metadata_settings[:host] = CrowbarHelper.get_host_for_admin_url(nova, ha_enabled)
      nova_metadata_settings[:port] = nova[:nova][:ports][:metadata]
      ssl_enabled = nova[:nova][:ssl][:enabled]
      ssl_insecure = nova[:nova][:ssl][:insecure]
    else
      ha_enabled = ec2api[:nova]["ec2-api"][:ha][:enabled]
      nova_metadata_settings[:host] = CrowbarHelper.get_host_for_admin_url(ec2api, ha_enabled)
      nova_metadata_settings[:port] = ec2api[:nova][:ports][:ec2_metadata]
      ssl_enabled = ec2api[:nova]["ec2-api"][:ssl][:enabled]
      ssl_insecure = ec2api[:nova]["ec2-api"][:ssl][:insecure]
    end

    # The same nova metadata proxy shared secret is used regardless of ec2-api presence
    nova_metadata_settings[:shared_secret] = nova[:nova][:neutron_metadata_proxy_shared_secret]
    nova_metadata_settings[:protocol] = ssl_enabled ? "https" : "http"
    nova_metadata_settings[:insecure] = ssl_enabled && ssl_insecure
  end

  keystone_settings = KeystoneHelper.keystone_settings(neutron, @cookbook_name)

  template "/etc/neutron/metadata_agent.ini" do
    source "metadata_agent.ini.erb"
    owner "root"
    group node[:neutron][:platform][:group]
    mode "0640"
    variables(
      debug: neutron[:neutron][:debug],
      keystone_settings: keystone_settings,
      auth_region: keystone_settings["endpoint_region"],
      neutron_insecure: neutron[:neutron][:ssl][:insecure],
      nova_metadata_settings: nova_metadata_settings
    )
  end

  unless use_cisco_apic_ml2_driver
    # In case of Cisco ACI driver, supervisord takes care of starting up
    # the metadata agent.
    service node[:neutron][:platform][:metadata_agent_name] do
      action [:enable, :start]
      subscribes :restart, resources(template: node[:neutron][:config_file])
      subscribes :restart, resources("template[/etc/neutron/metadata_agent.ini]")
      if neutron_network_ha || nova_compute_ha_enabled
        provider Chef::Provider::CrowbarPacemakerService
      end
      if nova_compute_ha_enabled
        supports no_crm_maintenance_mode: true
      else
        supports status: true, restart: true
      end
    end
  end
end
