define :cinder_service, use_pacemaker_provider: false do
  cinder_service_name="cinder-#{params[:name]}"
  cinder_name = cinder_service_name
  cinder_name = "openstack-cinder-#{params[:name]}" if %w(rhel suse).include? node[:platform_family]

  #TODO(agordeev):
  # be carefull, dpkg will not overwrite upstart configs
  # even if it be asked about that by 'confnew' option
  package cinder_name unless node[:platform_family] == "rhel"

  service cinder_service_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "stop #{cinder_name} ; start #{cinder_name}"
      stop_command "stop #{cinder_name}"
      start_command "start #{cinder_name}"
      status_command "status #{cinder_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    service_name cinder_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/cinder/cinder.conf")
    provider Chef::Provider::CrowbarPacemakerService if params[:use_pacemaker_provider]
  end
end
