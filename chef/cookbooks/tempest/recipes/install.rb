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

package "python-httplib2"
package "python-nose"
package "python-unittest2"


pip_cmd="pip install"

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

if nova[:nova][:use_gitrepo]!=true
  package "python-novaclient"
else
  execute "pip_install_clients_python-novaclient_for_tempest" do
    command "#{pip_cmd} 'python-glanceclient'"
  end
end
if glance[:glance][:use_gitrepo]!=true
  package "python-glanceclient"
else
  execute "pip_install_clients_python-glanceclient_for_tempest" do
    command "#{pip_cmd} 'python-glanceclient'"
  end
end


# Download and unpack tempest tarball

tarball_url = node[:tempest][:tempest_tarball]
filename = tarball_url.split('/').last
dst_dir = "/tmp"
inst_dir = node[:tempest][:tempest_path]

remote_file tarball_url do
  source tarball_url
  path "#{dst_dir}/#{filename}"
  action :create_if_missing
end

bash "install_tempest_with_rigth_path" do
  cwd dst_dir
  code <<-EOH
tar xf #{dst_dir}/#{filename}
mv openstack-tempest-* tempest
mkdir -p $(dirname #{inst_dir})
mv tempest $(dirname #{inst_dir})
EOH
  # TODO: use proposal attribute
  not_if { ::File.exists?("#{inst_dir}") }
end
