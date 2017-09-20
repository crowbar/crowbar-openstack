define :trove_service, use_pacemaker_provider: false do
  trove_service_name = "trove-#{params[:name]}"
  trove_name = trove_service_name
  trove_name = "openstack-trove-#{params[:name]}"\
                if ["rhel", "suse"].include? node[:platform_family]

  package trove_name if ["rhel", "suse"].include? node[:platform_family]

  service trove_service_name do
    service_name trove_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:trove][params[:name].to_sym][:config_file])
    provider Chef::Provider::CrowbarPacemakerService \
               if params[:use_pacemaker_provider]
  end
  utils_systemd_service_restart trove_service_name do
    action params[:use_pacemaker_provider] ? :disable : :enable
  end
end
