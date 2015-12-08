define :congress_service, use_pacemaker_provider: false do
  congress_service_name = "congress-#{params[:name]}"
  congress_name = congress_service_name
  congress_name = "openstack-congress-#{params[:name]}"\
                if %w(rhel suse).include? node[:platform_family]

  package congress_name if %w(rhel suse).include? node[:platform_family]

  service congress_service_name do
    service_name congress_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/congress/congress.conf")
    provider Chef::Provider::CrowbarPacemakerService \
               if params[:use_pacemaker_provider]
  end
end
