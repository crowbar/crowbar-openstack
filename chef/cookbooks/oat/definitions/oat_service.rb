define :oat_service do

  oat_name="oat-#{params[:name]}"

  service oat_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "restart #{oat_name}"
      stop_command "stop #{oat_name}"
      start_command "start #{oat_name}"
      status_command "status #{oat_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    supports :status => true, :restart => true
    action [:enable, :start]
    subscribes :restart, resources(:template => node[:inteltxt][:config_file])
  end

end
