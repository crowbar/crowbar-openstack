action :setup do
  execute "keystone-manage fernet_setup" do
    command "keystone-manage fernet_setup \
      --keystone-user #{node[:keystone][:user]} \
      --keystone-group #{node[:keystone][:group]}"
    action :run
  end
end

# attribute :rsync_command, kind_of: String, default: ""
action :rotate_script do
  template "/var/lib/keystone/keystone-fernet-rotate" do
    source "keystone-fernet-rotate.erb"
    owner "root"
    group node[:keystone][:group]
    mode "0750"
    variables(
      rsync_command: new_resource.rsync_command
    )
  end
end
