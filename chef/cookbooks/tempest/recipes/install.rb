#
# Cookbook Name:: tempest
# Recipe:: install
#
# Copyright 2011, Dell, Inc.
# Copyright 2012, Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# From the pip-requires -- all the Ubuntu packages for tempest prereqs
unless %w(redhat centos).include?(node.platform)
  packages = %w(python-anyjson python-nose python-httplib2 python-testtools python-lxml
     python-boto python-paramiko python-netaddr python-glanceclient
     python-keystoneclient python-novaclient python-neutronclient
     python-testresources python-keyring python-testrepository python-oslo.config)

  packages.each do |p|
    package p
  end
end

begin
  provisioner = search(:node, "roles:provisioner-server").first
  proxy_addr = provisioner[:fqdn]
  proxy_port = provisioner[:provisioner][:web_port]
  pip_cmd = "pip install --index-url http://#{proxy_addr}:#{proxy_port}/files/pip_cache/simple/"
rescue
  pip_cmd="pip install"
end

#check if nova and glance use gitrepo or package
env_filter = " AND nova_config_environment:nova-config-#{node[:tempest][:nova_instance]}"

novas = search(:node, "roles:nova-multi-controller#{env_filter}") || []
if novas.length > 0
  nova = novas[0]
  nova = node if nova.name == node.name
else
  nova = node
end

env_filter = " AND glance_config_environment:glance-config-#{nova[:nova][:glance_instance]}"

glances = search(:node, "roles:glance-server#{env_filter}") || []
if glances.length > 0
  glance = glances[0]
  glance = node if glance.name == node.name
else
  glance = node
end

# Download and unpack tempest tarball

tempest_path = node[:tempest][:tempest_path]
tarball_url = node[:tempest][:tempest_tarball]
filename = tarball_url.split('/').last

remote_file tarball_url do
  source tarball_url
  path File.join("tmp",filename)
  action :create_if_missing
end

bash "install_tempest_from_archive" do
  cwd "/tmp"
  code "tar xf #{filename} && mv openstack-tempest-* tempest && mv tempest /opt/ && rm #{filename}"
  not_if { ::File.exists?(tempest_path) }
end

unless %w(redhat centos).include?(node.platform)
  nosetests = `which nosetests`.strip
else
  #for centos we have to use nosetests from venv
  nosetests = "/opt/tempest/.venv/bin/nosetests"
end

if node[:tempest][:use_virtualenv]
  package("python-virtualenv")
  unless %w(redhat centos).include?(node.platform)
    package("python-dev")
  else
    package("python-devel")
    package("python-pip")
  end
  directory "/opt/tempest/.venv" do
    recursive true
    owner "root"
    group "root"
    mode  0775
    action :create
  end
  execute "virtualenv /opt/tempest/.venv --system-site-packages" unless File.exist?("/opt/tempest/.venv")
  pip_cmd = ". /opt/tempest/.venv/bin/activate && #{pip_cmd}"
  nosetests = "/opt/tempest/.venv/bin/python #{nosetests}"
end

if node[:tempest][:use_pfs]
  execute "pip_install_reqs_for_tempest" do
    cwd "/opt/tempest/"
    command "#{pip_cmd} -r /opt/tempest/requirements.txt"
  end
end

if nova[:nova][:use_gitrepo]!=true
  package "python-novaclient"
else
  execute "pip_install_clients_python-novaclient_for_tempest" do
    command "#{pip_cmd} 'python-novaclient'"
  end
end
if glance[:glance][:use_gitrepo]!=true
  package "python-glanceclient"
else
  execute "pip_install_clients_python-glanceclient_for_tempest" do
    command "#{pip_cmd} 'python-glanceclient'"
  end
end

