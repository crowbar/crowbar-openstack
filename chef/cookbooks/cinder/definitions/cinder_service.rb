define :cinder_service do

  cinder_name="cinder-#{params[:name]}"

  if node[:cinder][:use_gitrepo]
    link_service cinder_name do
      user node[:cinder][:user]
    end
  else
    package cinder_name
  end

  service cinder_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "stop #{cinder_name} ; start #{cinder_name}"
      stop_command "stop #{cinder_name}"
      start_command "start #{cinder_name}"
      status_command "status #{cinder_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    supports :status => true, :restart => true
    action [:enable, :start]
    subscribes :restart, resources(:template => "/etc/cinder/cinder.conf")
  end

end
