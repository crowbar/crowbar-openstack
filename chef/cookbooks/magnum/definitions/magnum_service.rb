define :magnum_service: do
  magnum_service_name = "magnum-#{params[:name]}"
  magnum_name = magnum_service_name
  magnum_name = "openstack-magnum-#{params[:name]}"\
                if %w(rhel suse).include? node[:platform_family]

  package magnum_name if %w(rhel suse).include? node[:platform_family]

  service magnum_service_name do
    service_name magnum_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/magnum/magnum.conf")
  end
