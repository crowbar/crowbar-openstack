define :cinder_service, :virtualenv => nil do

  cinder_name="cinder-#{params[:name]}"
  cinder_name="openstack-cinder-#{params[:name]}" if %w(redhat centos suse).include?(node.platform)

  cinder_path = "/opt/cinder"
  venv_path = node[:cinder][:use_virtualenv] ? "#{cinder_path}/.venv" : nil

  if node[:cinder][:use_gitrepo]
    link_service cinder_name do
      user node[:cinder][:user]
      virtualenv venv_path
    end
  else
    #TODO(agordeev):
    # be carefull, dpkg will not overwrite upstart configs
    # even if it be asked about that by 'confnew' option
    package cinder_name unless %w(redhat centos).include?(node.platform)
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
