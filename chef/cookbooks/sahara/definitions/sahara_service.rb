define :sahara_service, use_pacemaker_provider: false do
  sahara_service_name = "sahara-#{params[:name]}"
  sahara_name = sahara_service_name
  sahara_name = "openstack-sahara-#{params[:name]}"\
                if %w(rhel suse).include? node[:platform_family]

  package sahara_name if %w(rhel suse).include? node[:platform_family]

  service sahara_service_name do
    service_name sahara_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/sahara/sahara.conf")
    provider Chef::Provider::CrowbarPacemakerService \
               if params[:use_pacemaker_provider]
  end
end
