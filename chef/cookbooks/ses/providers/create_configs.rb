action :create do
  create_configs(new_resource.name)
end

def write_keyring_file(ses_config, service_name, group_name)
  Chef::Log.info("SES config write_keyring_file #{ses_config} for " \
                 "#{service_name} and group #{group_name}")
  client_name = ses_config[service_name]["rbd_store_user"]
  keyring_value = ses_config[service_name]["key"]
  Chef::Log.info("SES create #{service_name} keyring " \
                 "ceph.client.#{client_name}.keyring")
  template "/etc/ceph/ceph.client.#{client_name}.keyring" do
    cookbook "ses"
    source "client.keyring.erb"
    owner "root"
    group group_name.to_s
    mode "0644"
    variables(client_name: client_name,
              keyring_value: keyring_value)
  end
end

def create_configs(ses_service)
  # This recipe creates the /etc/ceph/ceph.conf
  # and the keyring files needed by the services
  # ses_service is the name of the service using ceph
  # which should be nova, cinder, glance
  Chef::Log.info("SES: create_configs for service #{ses_service}")

  ses_config = BarclampLibrary::Barclamp::Config.load(
    "openstack",
    "ses"
  )
  Chef::Log.info("SES config = #{ses_config}")
  # This is an external ceph cluster, it could be SES
  if !ses_config.nil? && !ses_config.empty?
    Chef::Log.info("Ceph is configred external and we found a SES proposal.")
    Chef::Log.info("SES create ceph.conf group '#{ses_service}'")
    # First create a unique clients list, so we don't have dupes in
    # the ceph.conf file
    ses_clients = {}
    user = ses_config["cinder"]["rbd_store_user"]
    ses_clients[user] = "ceph.client.#{user}.keyring"
    user = ses_config["cinder_backup"]["rbd_store_user"]
    ses_clients[user] = "ceph.client.#{user}.keyring"
    user = ses_config["glance"]["rbd_store_user"]
    ses_clients[user] = "ceph.client.#{user}.keyring"
    # SES is enabled, lets create the ceph.conf
    template "/etc/ceph/ceph.conf" do
      cookbook "ses"
      source "ceph.conf.erb"
      owner "root"
      group ses_service.to_s
      mode "0644"
      variables(fsid: ses_config["ceph_conf"]["fsid"],
                mon_initial_members: ses_config["ceph_conf"]["mon_initial_members"],
                mon_host: ses_config["ceph_conf"]["mon_host"],
                public_network: ses_config["ceph_conf"]["public_network"],
                cluster_network: ses_config["ceph_conf"]["cluster_network"],
                ses_clients: ses_clients)
    end

    # Now create the user keyring files
    write_keyring_file(ses_config, "cinder", ses_service)
    write_keyring_file(ses_config, "cinder_backup", ses_service)
    write_keyring_file(ses_config, "glance", ses_service)
  end
end
