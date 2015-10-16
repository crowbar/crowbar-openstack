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
    subscribes :restart, resources(template: "/etc/manila/manila.conf")
    provider Chef::Provider::CrowbarPacemakerService \
               if params[:use_pacemaker_provider]
  end
end
