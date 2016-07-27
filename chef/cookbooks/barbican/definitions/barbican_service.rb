define :barbican_service do
  barbican_service_name = "barbican-#{params[:name]}"
  barbican_name = barbican_service_name
  barbican_name = "openstack-barbican-#{params[:name]}"\
                if %w(rhel suse).include? node[:platform_family]

  package barbican_name if %w(rhel suse).include? node[:platform_family]

  service barbican_service_name do
    service_name barbican_name
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: "/etc/barbican/barbican.conf")
  end
end
