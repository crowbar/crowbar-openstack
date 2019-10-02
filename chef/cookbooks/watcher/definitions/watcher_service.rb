define :watcher_service do
  short_name = "#{params[:name]}"
  watcher_name = node[:watcher][short_name][:service_name]
  ha_enabled = node[:watcher][:ha][:enabled]

  utils_systemd_service_restart watcher_name do
    action :enable
  end

  service watcher_name do
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:watcher][short_name][:config_file])
  end
end
