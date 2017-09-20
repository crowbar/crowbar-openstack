define :glance_service do
  short_name    = "#{params[:name]}"
  glance_name   = node[:glance][short_name][:service_name]
  ha_enabled    = node[:glance][:ha][:enabled]
  use_crowbar_pacemaker_service = ha_enabled && node[:pacemaker][:clone_stateless_services]

  service glance_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "stop #{glance_name} ; start #{glance_name}"
      stop_command "stop #{glance_name}"
      start_command "start #{glance_name}"
      status_command "status #{glance_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:glance][short_name][:config_file])
    provider Chef::Provider::CrowbarPacemakerService if use_crowbar_pacemaker_service
  end
end
