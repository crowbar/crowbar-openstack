#
# Cookbook Name:: oat
# Recipe:: server
#
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set_unless['inteltxt']['db']['password'] = secure_password
node.set_unless['inteltxt']['password'] = secure_password

# prepare db
Chef::Log.info("Configuring OAT to use database backend")

include_recipe "mysql::client"

env_filter = " AND database_config_environment:database-config-#{node[:inteltxt][:database_instance]}"
sqls = search(:node, "roles:database-server#{env_filter}") || []
if sqls.length > 0
    sql = sqls[0]
    sql = node if sql.name == node.name
else
    sql = node
end

sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
Chef::Log.info("sql server found at #{sql_address}")

db_conn = { :host => sql_address,
            :username => "db_maker",
            :password => sql[:database][:db_maker_password] }
db_provider = Chef::Recipe::Database::Util.get_database_provider(sql)
db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql)
privs = Chef::Recipe::Database::Util.get_default_priviledges(sql)

database "create #{node[:inteltxt][:db][:database]} oat database" do
    connection db_conn
    database_name node[:inteltxt][:db][:database]
    action :create
    provider db_provider
end

database_user "create oat database user" do
    host '%' 
    connection db_conn
    username node[:inteltxt][:db][:user]
    password node[:inteltxt][:db][:password]
    provider db_user_provider
    action :create
end

database_user "grant database access for oat database user" do
    connection db_conn
    username node[:inteltxt][:db][:user]
    password node[:inteltxt][:db][:password]
    database_name node[:inteltxt][:db][:database]
    host '%'
    privileges privs
    provider db_user_provider
    action :grant
end


# installing package
# downloading it direclty because it can't be added to repository index
provisioners = search(:node, "roles:provisioner-server")
provisioner = provisioners[0] if provisioners
os_token="#{node[:platform]}-#{node[:platform_version]}"
repo_url = provisioner[:provisioner][:repositories][os_token][:inteltxt].keys.first.split(' ')[1]

pkg_name = "OAT-Appraiser-Base-OATapp-1.0.0-2.x86_64.deb"
pkg_path = "/root/#{pkg_name}"
remote_file pkg_path do
  source "#{repo_url}/#{pkg_name}"
  action :create_if_missing
end

#NOTE: package unpacks itself into /OAT-Appraiser-Base/
dpkg_package pkg_name do
  source pkg_path
end

[ "tomcat6", "zip", "unzip", "php5", "php5-mysql", "openssl" ].each { |p| package p }

#create dirs
[ "/etc/oat-appraiser", "/var/lib/oat-appraiser", "/var/lib/oat-appraiser/ClientFiles",
  "/var/lib/oat-appraiser/CaCerts", "/var/lib/oat-appraiser/Certificate", "/usr/share/oat-appraiser"
].each do |d|
  directory d do
    owner "tomcat6"
    group "tomcat6"
  end
end

inst_name = "OAT-Appraiser-Base"

execute "unzip_OAT_Setup" do
  command "unzip -o /#{inst_name}/OAT_Server_Install.zip -d /#{inst_name}/"
  not_if { File.exists? "/#{inst_name}/OAT_Server_Install/oat_db.MySQL" } 
end

execute "fix_sql_script" do
  command "sed -i -e '2d' /#{inst_name}/OAT_Server_Install/oat_db.MySQL"
  action :nothing
  subscribes :run, "execute[unzip_OAT_Setup]", :immediately
end

[ "oat_db.MySQL", "init.sql" ].each do |f|
  execute "create_tables_for_oat" do
    command "mysql -u #{node[:inteltxt][:db][:user]} -p#{node[:inteltxt][:db][:password]} -h #{sql_address} #{node[:inteltxt][:db][:database]} < /#{inst_name}/OAT_Server_Install/#{f}"
    ignore_failure true
    action :nothing
    subscribes :run, "execute[unzip_OAT_Setup]", :immediately
  end
end

#create keystore
execute "add_hostname_to_host" do
  command 'echo "127.0.0.1 `hostname`" >> /etc/hosts'
  not_if "grep `hostname` /etc/hosts"
end

node.set_unless[:inteltxt][:keystore_pass] = secure_password
node.set_unless[:inteltxt][:truststore_pass] = secure_password

bash "create_keystore_and_truststore" do
  cwd "/var/lib/oat-appraiser/Certificate"
  code <<-EOH
  openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout hostname.pem -out hostname.cer -subj "/C=US/O=U.S. Government/OU=DoD/CN=#{node[:fqdn]}"
  openssl pkcs12 -export -in hostname.cer -inkey hostname.pem -out $p12file -passout pass:$p12pass
  keytool -importkeystore -srckeystore $p12file -destkeystore $keystore -srcstoretype pkcs12 -srcstorepass $p12pass -deststoretype jks -deststorepass $p12pass -noprompt
  myalias=`keytool -list -v -keystore $keystore -storepass $p12pass | grep -B2 'PrivateKeyEntry' | grep 'Alias name:'`
  keytool -changealias -alias ${myalias#*:} -destalias tomcat -v -keystore $keystore -storepass $p12pass
  rm -f $truststore
  keytool -import -keystore $truststore -storepass $truststore_pass -file hostname.cer -noprompt
  EOH
  environment({
    'p12pass' => node[:inteltxt][:keystore_pass],
    'truststore_pass' => node[:inteltxt][:truststore_pass],
    'p12file' => 'internal.p12',
    'keystore' => 'keystore.jks',
    'truststore' => 'TrustStore.jks'
  })
  ignore_failure true
  not_if { File.exists? "/var/lib/oat-appraiser/Certificate/TrustStore.jks" }
end

# install and
# configure tomcat6

webapp_dir = "/usr/share/oat-appraiser/webapps"
[ "AttestationService", "HisPrivacyCAWebServices2", 
  "HisWebServices", "WLMService"].each do |webapp|
  template "/etc/oat-appraiser/#{webapp}.xml" do
    mode 0640
    owner "tomcat6"
    group "tomcat6"
    source "webapp.xml.erb"
    variables({
      :resource_name => webapp,
      :webapp_path => webapp_dir,
      :db_user => node[:inteltxt][:db][:user],
      :db_pass => node[:inteltxt][:db][:password],
      :db_name => node[:inteltxt][:db][:database],
      :mysql_host => sql_address
    })
  end
  execute "link_service_#{webapp}" do
    command "ln -sf /etc/oat-appraiser/#{webapp}.xml /etc/tomcat6/Catalina/localhost/"
    not_if { File.symlink? "/etc/tomcat6/Catalina/localhost/#{webapp}.xml" }
  end
  directory "#{webapp_dir}/#{webapp}" do
    mode 0755
    owner "tomcat6"
    group "tomcat6"
    recursive true
  end
end

template "/etc/oat-appraiser/server.xml" do
  mode 0640
  owner "tomcat6"
  group "tomcat6"
  source "server.xml.erb"
  variables(
    :listen_IP => Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  )
end

bash "deploy_server_xml" do
  code <<-EOH
  rm -f /etc/tomcat6/server.xml
  rm -f /var/lib/tomcat6/conf/server.xml
  ln -sf /etc/oat-appraiser/server.xml /etc/tomcat6/server.xml
  ln -sf /etc/oat-appraiser/server.xml /var/lib/tomcat6/conf/server.xml
  EOH
  not_if { File.symlink? "/etc/tomcat6/server.xml" }
end

bash "deploy_wars" do
  environment("WEBAPP_DIR" => webapp_dir, "name" => inst_name)
  cwd "/#{inst_name}"
  code <<-EOH
  unzip -o /$name/OAT_Server_Install.zip -d /$name/
  cp -R /$name/OAT_Server_Install/HisWebServices $WEBAPP_DIR/
  unzip -o /$name/OAT_Server_Install/WLMService.war -d $WEBAPP_DIR/WLMService 
  unzip -o /$name/OAT_Server_Install/AttestationService.war -d $WEBAPP_DIR/AttestationService 
  unzip -o /$name/HisPrivacyCAWebServices2.war -d $WEBAPP_DIR/HisPrivacyCAWebServices2
  rm $WEBAPP_DIR/AttestationService/WEB-INF/classes/OpenAttestationWebServices.properties /etc/oat-appraiser/OpenAttestationWebServices.properties
  cp /$name/OAT_Server_Install/hibernateOat.cfg.xml $WEBAPP_DIR/HisWebServices/WEB-INF/classes/
  rm $WEBAPP_DIR/HisWebServices/WEB-INF/classes/OpenAttestation.properties /etc/oat-appraiser/
  rm -rf $WEBAPP_DIR/HisPrivacyCAWebServices2/CaCerts
  rm -rf $WEBAPP_DIR/HisPrivacyCAWebServices2/ClientFiles/
EOH
  not_if { File.exists? "/usr/share/oat-appraiser/webapps/HisWebServices/WEB-INF" }
end

#NOTE(agordeev): move this into template later
execute "deploy_setup.properties" do
  command "unzip -o /#{inst_name}/setupProperties.zip -d /etc/oat-appraiser"
  not_if { File.exists? "/etc/oat-appraiser/setup.properties" }
end

[ "/etc/oat-appraiser", "/var/lib/oat-appraiser"].each do |d|
  execute "fix_file_permissions_for_#{d}" do
    command "chown -R tomcat6:tomcat6 #{d}"
    action :nothing
    subscribes :run, "bash[create_keystore_and_truststore]", :immediately
    #not_if { File.stat(d).uid > 0 }
  end
end

[ "OpenAttestation", "OpenAttestationWebServices", "OAT" ].each do |prop|
  template "/etc/oat-appraiser/#{prop}.properties" do
    mode 0640
    owner "tomcat6"
    group "tomcat6"
    source "#{prop}.properties.erb"
  end
end

service "tomcat6" do
  action [ :enable, :start ]
  subscribes :restart, "bash[deploy_wars]", :immediately
  subscribes :restart, "bash[create_keystore_and_truststore]", :immediately
  subscribes :restart, "bash[deploy_server_xml]", :immediately
  subscribes :restart, "template[/etc/oat-appraiser/OpenAttestation.properties]", :immediately
  subscribes :restart, "template[/etc/oat-appraiser/OpenAttestationWebServices.properties]", :immediately
  subscribes :restart, "template[/etc/oat-appraiser/OAT.properties]", :immediately
end

node[:apache][:listen_ports] << node[:inteltxt][:apache_listen_port] unless node[:apache][:listen_ports].include? node[:inteltxt][:apache_listen_port]
include_recipe "apache2"

template "#{node[:apache][:dir]}/sites-available/oat_vhost" do
  source "oat_vhost.erb"
  mode 0644
  variables(
      :oat_dir => "/var/www/OAT"
  )
  if ::File.symlink?("#{node[:apache][:dir]}/sites-enabled/oat_vhost")
    notifies :reload, resources(:service => "apache2")
  end
end

apache_site "oat_vhost" do
  enable true
end

bash "deploy_his_portal" do
  environment("name" => inst_name)
  code <<-EOH
  rm -rf /${name}/OAT
  unzip -o /${name}/OAT.zip -d /${name}/
  rm -rf /var/www/OAT
  mv -f /${name}/OAT /var/www/OAT
  rm -f /var/www/OAT/ClientInstallForLinux.zip
  EOH
  not_if { File.exists? "/var/www/OAT" }
  subscribes :run, "ruby_block[sleep_after_startup]", :immediately
end

template "/var/www/OAT/includes/dbconnect.php" do
  source "dbconnect.php.erb"
  variables(
    :db_user => node[:inteltxt][:db][:user],
    :db_pass => node[:inteltxt][:db][:password],
    :db_name => node[:inteltxt][:db][:database],
    :db_host => sql_address
  )
  notifies :restart, "service[apache2]"  
end

# appraiser will create PrivacyCA only after successful startup
ruby_block "sleep_after_startup" do
  block do
    sleep 60 
  end
  action :nothing
  not_if { File.exists? "/var/www/OAT/ClientInstallForLinux.zip" }
  subscribes :create, "service[tomcat6]", :immediately
end

# prepare agent
bash "prepare_agent" do
  cwd "/#{inst_name}"
  code <<-EOH
    out_dir=ClientInstallForLinux
    unzip ${out_dir}.zip -d .
    rm -f ${out_dir}.zip
    cp -r -f linuxOatInstall ${out_dir}
    cp OAT_Standalone.jar ${out_dir}/
    cp -r lib ${out_dir}/ 
    cp -r -f /var/lib/oat-appraiser/ClientFiles/PrivacyCA.cer ${out_dir}/
    cp -r -f /var/lib/oat-appraiser/ClientFiles/TrustStore.jks ${out_dir}/
    zip -9 -r ${out_dir}.zip ${out_dir}
    cp ${out_dir}.zip /var/www/OAT/
  EOH
  action :run
  subscribes :run, "bash[deploy_his_portal]", :immediately
  not_if { File.exists? "/var/www/OAT/ClientInstallForLinux.zip" and node[:inteltxt][:server][:client_package_ready] }
  only_if { File.exists? "/var/lib/oat-appraiser/ClientFiles/PrivacyCA.cer" }
  only_if { File.exists? "/var/lib/oat-appraiser/ClientFiles/TrustStore.jks" }
end

# appraiser will create PrivacyCA only after successful startup
ruby_block "set_client_package_ready" do
  block do
    node.set[:inteltxt][:server][:client_package_ready] = true
    node.save
  end
  action :nothing
  subscribes :create, "bash[prepare_agent]", :immediately
end

include_recipe "oat::server-pcr"
node.save
