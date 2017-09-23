define :manila_service, use_pacemaker_provider: false do
  manila_service_name = "manila-#{params[:name]}"
  manila_name = manila_service_name
  manila_name = "openstack-manila-#{params[:name]}"\
                if %w(rhel suse).include? node[:platform_family]

  package manila_name if %w(rhel suse).include? node[:platform_family]

  service manila_service_name do
    service_name manila_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:manila][:config_file])
    provider Chef::Provider::CrowbarPacemakerService \
               if params[:use_pacemaker_provider]
  end
  utils_systemd_service_restart manila_service_name do
    action params[:use_pacemaker_provider] ? :disable : :enable
  end
end
