# Copyright 2014 SUSE
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

use_l3_agent = (node[:neutron][:networking_plugin] != "vmware" &&
                !node[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2") &&
                !node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp"))
use_lbaas_agent = node[:neutron][:use_lbaas]
use_metadata_agent = (!node[:neutron][:ml2_mechanism_drivers].include?("cisco_apic_ml2") &&
                      !node[:neutron][:ml2_mechanism_drivers].include?("apic_gbp"))

if use_l3_agent
  # do the setup required for neutron-ha-tool
  package node[:neutron][:platform][:ha_tool_pkg] unless node[:neutron][:platform][:ha_tool_pkg] == ""

  keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)

  # FIXME: While the neutron-ha-tool resource agent allows specifying a CA
  # Certificate to use for SSL Certificate verification, it's hard to select
  # right CA file as we allow Keystone's and Neutron's to use different CAs.  So
  # we just rely on the correct CA files being installed in a system wide default
  # location.
  file "/etc/neutron/os_password" do
    owner "root"
    group "root"
    mode "0600"
    content keystone_settings["service_password"]
    # Our Chef is apparently too old for this :-/
    #sensitive true
    action :create
  end

  # We need .openrc present at network node so the node can use neutron-ha-tool even
  # when located in separate cluster
  template "/root/.openrc" do
    source "openrc.erb"
    cookbook "keystone"
    owner "root"
    group "root"
    mode 0o600
    variables(
      keystone_settings: keystone_settings
    )
  end

  # skip neutron-ha-tool resource creation during upgrade
  unless CrowbarPacemakerHelper.being_upgraded?(node)

    os_auth_url = KeystoneHelper.versioned_service_URL(keystone_settings["protocol"],
                                                          keystone_settings["internal_url_host"],
                                                          keystone_settings["service_port"],
                                                          keystone_settings["api_version"])

    # Add configuration file
    insecure_flag = keystone_settings["insecure"] || node[:neutron][:ssl][:insecure]
    default_settings = node[:neutron][:ha][:neutron_l3_ha_service].to_hash
    config_file_contents = NeutronHelper.make_l3_ha_service_config default_settings,
                                                                   insecure_flag do |env|
      env["OS_AUTH_URL"] = os_auth_url
      env["OS_AUTH_VERSION"] = keystone_settings["api_version"]
      env["OS_REGION_NAME"] = keystone_settings["endpoint_region"]
      env["OS_PROJECT_NAME"] = keystone_settings["service_project"]
      env["OS_USERNAME"] = keystone_settings["service_user"]
      env["OS_USER_DOMAIN_NAME"] = keystone_settings["default_user_domain"]
      env["OS_PROJECT_DOMAIN_NAME"] = keystone_settings["default_user_domain"]
    end

    file "/etc/neutron/neutron-l3-ha-service.yaml" do
      owner "root"
      group "root"
      mode "0600"
      content config_file_contents
      action :create
    end

    # Install service script
    cookbook_file "neutron-l3-ha-service.rb" do
      source "neutron-l3-ha-service.rb"
      path "/usr/bin/neutron-l3-ha-service"
      mode "0755"
      owner "root"
      group "root"
    end

    # install systemd unit configuration
    systemd_kill_timeout = NeutronHelper.max_kill_timeout(
      node[:neutron][:ha][:neutron_l3_ha_service][:timeouts]
    ) + 5

    template "/etc/systemd/system/neutron-l3-ha-service.service" do
      source "neutron-l3-ha-service.service.erb"
      mode "0644"
      owner "root"
      group "root"
      variables(
        timeout_in_seconds: systemd_kill_timeout
      )
    end

    # Reload systemd when unit file changed
    bash "reload systemd after neutron-l3-ha-service update" do
      code "systemctl daemon-reload"
      action :nothing
      subscribes :run, resources("template[/etc/systemd/system/neutron-l3-ha-service.service]"),
        :immediately
    end
  end
end

# Wait for all "neutron-network" nodes to reach this point so we know that they will
# have all the required packages installed and configuration files updated
# before we create the pacemaker resources.
crowbar_pacemaker_sync_mark "sync-neutron-agents_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-neutron-agents_ha_resources" do
  timeout 90
end

if node[:pacemaker][:clone_stateless_services]
  transaction_objects = []

  if use_l3_agent
    case node[:neutron][:networking_plugin]
    when "ml2"
      ml2_mech_drivers = node[:neutron][:ml2_mechanism_drivers]
      if ml2_mech_drivers.include?("openvswitch")
        neutron_agent = node[:neutron][:platform][:ovs_agent_name]
        neutron_agent_ra = node[:neutron][:ha][:network]["openvswitch_ra"]
      elsif ml2_mech_drivers.include?("linuxbridge")
        neutron_agent = node[:neutron][:platform][:lb_agent_name]
        neutron_agent_ra = node[:neutron][:ha][:network]["linuxbridge_ra"]
      end
    when "vmware"
      neutron_agent = ""
      neutron_agent_ra = ""
    end
    neutron_agent_primitive = neutron_agent.sub(/^openstack-/, "")

    objects = openstack_pacemaker_controller_clone_for_transaction neutron_agent_primitive do
      agent neutron_agent_ra
      op node[:neutron][:ha][:network][:op]
    end
    transaction_objects.push(objects)
  end

  dhcp_agent_primitive = "neutron-dhcp-agent"
  objects = openstack_pacemaker_controller_clone_for_transaction dhcp_agent_primitive do
    agent node[:neutron][:ha][:network][:dhcp_ra]
    op node[:neutron][:ha][:network][:op]
  end
  transaction_objects.push(objects)

  if use_l3_agent
    # The L2 agent must start before DHCP agent as DHCP agent depends on it.
    # Otherwise, this can result in port failing to bind.
    l2_dhcp_order_name = "o-cl-neutron-l2-dhcp-agents"
    pacemaker_order l2_dhcp_order_name do
      ordering "cl-#{neutron_agent_primitive} cl-#{dhcp_agent_primitive}"
      score "Optional"
      action :update
      only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
    transaction_objects << "pacemaker_order[#{l2_dhcp_order_name}]"

    l3_agent_primitive = "neutron-l3-agent"
    objects = openstack_pacemaker_controller_clone_for_transaction l3_agent_primitive do
      agent node[:neutron][:ha][:network][:l3_ra]
      op node[:neutron][:ha][:network][:op]
    end
    transaction_objects.push(objects)

    l3_agent_clone = "cl-#{l3_agent_primitive}"
  end

  enable_metadata = node.roles.include?("neutron-network") || !node[:neutron][:metadata][:force]

  metadata_agent_primitive = "neutron-metadata-agent"
  if use_metadata_agent && enable_metadata
    objects = openstack_pacemaker_controller_clone_for_transaction metadata_agent_primitive do
      agent node[:neutron][:ha][:network][:metadata_ra]
      op node[:neutron][:ha][:network][:op]
    end
    transaction_objects.push(objects)
  else
    pacemaker_primitive metadata_agent_primitive do
      agent node[:neutron][:ha][:network][:metadata_ra]
      action [:stop, :delete]
      only_if "crm configure show #{metadata_agent_primitive}"
    end
  end

  metering_agent_primitive = "neutron-metering-agent"
  objects = openstack_pacemaker_controller_clone_for_transaction metering_agent_primitive do
    agent node[:neutron][:ha][:network][:metering_ra]
    op node[:neutron][:ha][:network][:op]
  end
  transaction_objects.push(objects)

  if use_lbaas_agent &&
      [nil, "", "haproxy"].include?(node[:neutron][:lbaasv2_driver])
    lbaas_agent_primitive = "neutron-lbaasv2-agent"
    objects = openstack_pacemaker_controller_clone_for_transaction lbaas_agent_primitive do
      agent node[:neutron][:ha][:network][:lbaasv2_ra]
      op node[:neutron][:ha][:network][:op]
    end
    transaction_objects.push(objects)
  end

  if use_lbaas_agent && node[:neutron][:lbaasv2_driver] == "f5"
    f5_agent_primitive = "neutron-f5-agent"
    objects = openstack_pacemaker_controller_clone_for_transaction f5_agent_primitive do
      agent node[:neutron][:ha][:network][:f5_ra]
      op node[:neutron][:ha][:network][:op]
    end
    transaction_objects.push(objects)
  end

  pacemaker_transaction "neutron agents" do
    cib_objects transaction_objects.flatten
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
else
  l3_agent_primitive = "neutron-l3-agent"
  l3_agent_clone = "cl-#{l3_agent_primitive}"
end

if CrowbarPacemakerHelper.being_upgraded?(node)
  log "Skipping neutron-ha-tool resource creation during the upgrade"
  use_l3_agent = false
end

if use_l3_agent
  # Remove old resource
  ha_tool_primitive_name = "neutron-ha-tool"
  pacemaker_primitive ha_tool_primitive_name do
    agent node[:neutron][:ha][:network][:ha_tool_ra]
    action [:stop, :delete]
    only_if "crm configure show #{ha_tool_primitive_name}"
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  # Remove old location
  ha_tool_location_name = "l-#{ha_tool_primitive_name}-controller"
  pacemaker_location ha_tool_location_name do
    action :delete
    only_if "crm configure show #{ha_tool_location_name}"
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  # Remove old ordering
  ha_tool_ordering_name = "o-#{ha_tool_primitive_name}"
  pacemaker_order ha_tool_ordering_name do
    action :delete
    only_if "crm configure show #{ha_tool_ordering_name}"
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  # Add pacemaker resource for neutron-l3-ha-service
  ha_service_transaction_objects = []
  ha_service_primitive_name = "neutron-l3-ha-service"

  pacemaker_primitive ha_service_primitive_name do
    agent "systemd:neutron-l3-ha-service"
    op node[:neutron][:ha][:neutron_l3_ha_resource][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  ha_service_transaction_objects << "pacemaker_primitive[#{ha_service_primitive_name}]"

  ha_service_location_name = openstack_pacemaker_controller_only_location_for(
    ha_service_primitive_name
  )

  ha_service_transaction_objects << "pacemaker_location[#{ha_service_location_name}]"

  pacemaker_transaction "neutron ha service" do
    cib_objects ha_service_transaction_objects
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  rabbit_settings = fetch_rabbitmq_settings

  crowbar_pacemaker_order_only_existing "o-#{ha_service_primitive_name}" do
    # While neutron-ha-tool technically doesn't directly depend on postgresql or
    # rabbitmq, if these bits are not running, then neutron-server can run but
    # can't do what it's being asked. Note that neutron-server does have a
    # constraint on these services, but it's optional, not mandatory (because it
    # doesn't need to be restarted when postgresql or rabbitmq are restarted).
    # So explicitly depend on postgresql and rabbitmq (if they are in the cluster).
    ordering "( postgresql #{rabbit_settings[:pacemaker_resource]} g-haproxy cl-neutron-server " \
             "#{l3_agent_clone} ) #{ha_service_primitive_name}"
    score "Mandatory"
    action :create
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

crowbar_pacemaker_sync_mark "create-neutron-agents_ha_resources"
