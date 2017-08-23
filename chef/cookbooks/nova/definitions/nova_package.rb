# Copyright 2011, Dell
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
define :nova_package, enable: true, use_pacemaker_provider: false, restart_crm_resource: false, no_crm_maintenance_mode: false do
  nova_name="nova-#{params[:name]}"

  package nova_name do
    package_name "openstack-#{nova_name}" if %w(rhel suse).include?(node[:platform_family])
    action :install
  end

  service nova_name do
    service_name "openstack-#{nova_name}" if %w(rhel suse).include?(node[:platform_family])
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "stop #{nova_name} ; start #{nova_name}"
      stop_command "stop #{nova_name}"
      start_command "start #{nova_name}"
      status_command "status #{nova_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end

    if params[:use_pacemaker_provider]
      supports restart_crm_resource: params[:restart_crm_resource], \
               no_crm_maintenance_mode: params[:no_crm_maintenance_mode], \
               pacemaker_resource_name: nova_name
    else
      supports status: true, restart: true
    end

    if params[:enable] != false
      # only enable and start the service, unless a reboot has been triggered
      # (e.g. because of switching from # kernel-default to kernel-xen)
      unless node.run_state[:reboot]
        action [:enable, :start]
      else
        # start will happen after reboot, and potentially even fail before
        # reboot (ie. on installing kernel-xen + expecting libvirt to already
        # use xen before)
        if node[:platform_family] == "rhel"
          #needed until https://bugs.launchpad.net/oslo/+bug/1177184 is solved
          action [:enable, :start]
        else
          action [:enable]
        end
      end
    end

    subscribes :restart, [resources(template: node[:nova][:config_file]),
                          resources(template: node[:nova][:placement_config_file])]

    provider Chef::Provider::CrowbarPacemakerService if params[:use_pacemaker_provider]
  end
  utils_systemd_service_restart nova_name do
    action params[:use_pacemaker_provider] ? :disable : :enable
  end
end
