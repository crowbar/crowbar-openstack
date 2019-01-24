#
# Cookbook Name:: nova
# Recipe:: vncproxy
#
# Copyright 2009, Example Com
# Copyright 2011, Dell Inc.
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

include_recipe "nova::config"

unless %w(rhel suse).include?(node[:platform_family])
  pkgs = %w[python-numpy nova-console]
  pkgs.each do |pkg|
    package pkg
  end
end

# forcing novnc is deliberate on suse
if node[:nova][:use_novnc]
  if %w(rhel suse).include?(node[:platform_family])
    package "openstack-nova-novncproxy"
  else
    package "nova-novncproxy"
  end

  service "nova-novncproxy" do
    service_name "openstack-nova-novncproxy" if %w(rhel suse).include?(node[:platform_family])
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:nova][:config_file]), :delayed
  end
  utils_systemd_service_restart "nova-novncproxy" do
    action :enable
  end
end

if node[:nova][:use_serial]
  if ["rhel", "suse"].include?(node[:platform_family])
    package "openstack-nova-serialproxy"
  end
  service "nova-serialproxy" do
    service_name "openstack-nova-serialproxy" if ["rhel", "suse"].include?(node[:platform_family])
    supports status: true, restart: true
    action [:enable, :start]
    subscribes :restart, resources(template: node[:nova][:config_file]), :delayed
  end
  utils_systemd_service_restart "nova-serialproxy" do
    action :enable
  end
end
