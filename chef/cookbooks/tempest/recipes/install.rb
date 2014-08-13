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

begin
  provisioner = search(:node, "roles:provisioner-server").first
  proxy_addr = provisioner[:fqdn]
  proxy_port = provisioner[:provisioner][:web_port]
  pip_cmd = "pip install --index-url http://#{proxy_addr}:#{proxy_port}/files/pip_cache/simple/"
rescue
  pip_cmd="pip install"
end

#needed to create venv correctly
if %w(redhat centos).include?(node.platform)
  package "libxslt-devel"
el
  package "libxslt1-dev"
end

if %w(suse).include?(node.platform)
  #needed for tempest.tests.test_wrappers.TestWrappers.test_pretty_tox
  package "git-core"
else
  #needed for tempest.tests.test_wrappers.TestWrappers.test_pretty_tox
  package "git"
end

#needed for ec2 and s3 test suite
package "euca2ools"

if node[:tempest][:use_gitrepo]
  # Download and unpack tempest tarball

  tarball_url = node[:tempest][:tempest_tarball]
  filename = tarball_url.split('/').last

  remote_file tarball_url do
    source tarball_url
    path File.join("tmp",filename)
    action :create_if_missing
  end

  parent_tempest_path = File.dirname(node[:tempest][:tempest_path])

  directory parent_tempest_path do
    recursive true
    owner "root"
    group "root"
    mode  0755
    action :create
  end

  bash "install_tempest_from_archive" do
    cwd "/tmp"
    code "tar xf #{filename} && mv openstack-tempest-* tempest && mv tempest #{node[:tempest][:tempest_path]} && rm #{filename}"
    not_if { ::File.exists?(node[:tempest][:tempest_path]) }
  end

  if node[:tempest][:use_virtualenv]
    package "python-virtualenv"
    unless %w(redhat centos).include?(node.platform)
      package "python-dev"
    else
      package "python-devel"
      package "python-pip"
      package "libxslt-devel"
    end
    directory "#{node[:tempest][:tempest_path]}/.venv" do
      recursive true
      owner "root"
      group "root"
      mode  0775
      action :create
    end
    execute "virtualenv #{node[:tempest][:tempest_path]}/.venv" unless File.exist?("#{node[:tempest][:tempest_path]}/.venv")
    pip_cmd = ". #{node[:tempest][:tempest_path]}/.venv/bin/activate && #{pip_cmd}"
  end

  execute "pip_install_reqs_for_tempest" do
    cwd "#{node[:tempest][:tempest_path]}"
    command "#{pip_cmd} -r #{node[:tempest][:tempest_path]}/requirements.txt"
  end
else
  package "openstack-tempest-test"
end

package "python-novaclient"
package "python-glanceclient"
