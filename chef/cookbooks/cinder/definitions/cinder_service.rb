define :cinder_service do

  cinder_name="cinder-#{params[:name]}"

  service cinder_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "restart #{cinder_name}"
      stop_command "stop #{cinder_name}"
      start_command "start #{cinder_name}"
      status_command "status #{cinder_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    supports :status => true, :restart => true
    action [:enable, :start]
    subscribes :restart, resources(:template => node[:cinder][:config_file])
  end

end
