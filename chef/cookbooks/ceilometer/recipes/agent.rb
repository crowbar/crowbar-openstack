# Copyright 2011 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

unless node[:ceilometer][:use_gitrepo]
  package "ceilometer-agent-compute" do
    if %w(suse).include?(node.platform)
      package_name "openstack-ceilometer-agent-compute"
    elsif %w(redhat centos).include?(node.platform)
      package_name "openstack-ceilometer-compute"
    end
    action :install
  end
else
  ceilometer_path = "/opt/ceilometer"

  venv_path = node[:ceilometer][:use_virtualenv] ? "#{ceilometer_path}/.venv" : nil
  venv_prefix = node[:ceilometer][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil
  puts "venv_path=#{venv_path}"
  puts "use_virtualenv=#{node[:ceilometer][:use_virtualenv]}"
  pfs_and_install_deps "ceilometer" do
    cookbook "ceilometer"
    cnode node
    virtualenv venv_path
    path ceilometer_path
    wrap_bins [ "ceilometer" ]
  end

  link_service "ceilometer-agent-compute" do
    virtualenv venv_path
  end

  create_user_and_dirs(@cookbook_name)
  execute "cp_policy.json" do
    command "cp #{ceilometer_path}/etc/ceilometer/policy.json /etc/ceilometer"
    creates "/etc/ceilometer/policy.json"
  end
  execute "cp_pipeline.yaml" do
    command "cp #{ceilometer_path}/etc/ceilometer/pipeline.yaml /etc/ceilometer"
    creates "/etc/ceilometer/pipeline.yaml"
  end
end

include_recipe "#{@cookbook_name}::common"

service "ceilometer-agent-compute" do
  if %w(suse).include?(node.platform)
    service_name "openstack-ceilometer-agent-compute"
  elsif %w(redhat centos).include?(node.platform)
    service_name "openstack-ceilometer-compute"
  end
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, resources("template[/etc/ceilometer/ceilometer.conf]")
end
