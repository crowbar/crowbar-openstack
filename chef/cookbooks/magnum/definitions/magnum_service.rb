define :magnum_service, use_pacemaker_provider: false do
  magnum_service_name = "magnum-#{params[:name]}"
  magnum_name = magnum_service_name
  magnum_name = "openstack-magnum-#{params[:name]}"\
                if %w(rhel suse).include? node[:platform_family]

  package magnum_name if %w(rhel suse).include? node[:platform_family]

  service magnum_service_name do
    service_name magnum_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:magnum][:config_file])
    provider Chef::Provider::CrowbarPacemakerService \
               if params[:use_pacemaker_provider]
  end
  utils_systemd_service_restart magnum_service_name do
    action params[:use_pacemaker_provider] ? :disable : :enable
  end
end
