#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2009, Benjamin Black
# Copyright 2009-2011, Opscode, Inc.
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

service "rabbitmq-server" do
  supports :restart => true, :start => true, :stop => true
  action :nothing
end

directory "/etc/rabbitmq/" do
  owner "root"
  group "root"
  mode 0755
  action :create
end

template "/etc/rabbitmq/rabbitmq-env.conf" do
  source "rabbitmq-env.conf.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[rabbitmq-server]"
end

template "/etc/rabbitmq/rabbitmq.config" do
  source "rabbitmq.config.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[rabbitmq-server]"
end

package "rabbitmq-server"
package "rabbitmq-server-plugins" if node.platform == "suse"



rabbitmq_plugins = "#{RbConfig::CONFIG["libdir"]}/rabbitmq/bin/rabbitmq-plugins"
rabbitmq_plugins = "/usr/sbin/rabbitmq-plugins" if node.platform?(%w{"redhat" "centos"})

if node.platform?(%w{"redhat" "centos"})
  rpm_url = node[:rabbitmq][:rabbitmq_rpm]
  filename = rpm_url.split('/').last

  bash "install proper rabbit server" do
    code "rpm -Uvh #{File.join("tmp",filename)}"
    notifies :restart, "service[rabbitmq-server]", :immediately
    action :nothing
  end

  remote_file rpm_url do
    source rpm_url
    path File.join("tmp",filename)
    action :create_if_missing
    notifies :run, resources(:bash => "install proper rabbit server"), :immediately
  end

end

bash "enabling rabbit management" do
  code "#{rabbitmq_plugins} enable rabbitmq_management > /dev/null"
  not_if "#{rabbitmq_plugins} list -E | grep rabbitmq_management -q"
  notifies :restart, "service[rabbitmq-server]", :immediately
end

