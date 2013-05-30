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

## use the RabbitMQ repository instead of Ubuntu or Debian's
## because there are very useful features in the newer versions
#apt_repository "rabbitmq" do
#  uri "http://www.rabbitmq.com/debian/"
#  distribution "testing"
#  components ["main"]
#  key "http://www.rabbitmq.com/rabbitmq-signing-key-public.asc"
#  action :add
#end

execute "stop rabbitmq" do
  command "rabbitmqctl stop; ps aux |awk '/^rabbit/ {print $2}' |xargs kill || :"
  only_if "which rabbitmqctl && rabbitmqctl status"
  action :nothing
end

# Sigh, silly debian package starting rabbit by default.
package "rabbitmq-server" do
  action :install
  notifies :run, "execute[stop rabbitmq]", :immediately
end

directory "/etc/rabbitmq/" do
  owner "root"
  group "root"
  mode 0755
  action :create
end

user "rabbitmq" do
  action :create
  home "/var/lib/rabbitmq"
end

%w{ /var/log/rabbitmq /var/lib/rabbitmq }.each { |dir|
  directory dir do
    action :create
    owner "rabbitmq"
    group "rabbitmq"
  end
}

template "/etc/rabbitmq/rabbitmq-env.conf" do
  source "rabbitmq-env.conf.erb"
  owner "root"
  group "root"
  notifies :restart, "service[rabbitmq-server]"
  mode 0644
end

template "/etc/rabbitmq/rabbitmq.config" do
  source "rabbitmq.config.erb"
  owner "root"
  group "root"
  mode 0644
  notifies :restart, "service[rabbitmq-server]"
end

# Sigh, rabbitmqctl wants to parse the rabbitmq config files to
# find the running instances.  Guess what happens when we change them while
# rabbit is running, and guess what knock-on effects exist in the rabbit
# init scripts.
service "rabbitmq-server" do
  supports :status => true
  unless node.platform == "suse"
    # This is a big, ugly hammer, but when your control program and the
    # init scripts that use it are misdesigned, you do what you have to.
    stop_command "service rabbitmq-server stop; rabbitmqctl stop; ps aux |awk '/^rabbitmq/ {print $2}' |xargs kill || :"
    # For now, assume that rabbitmq is runnning if any processes owned
    # by rabbitmq are present, even if rabbitmqctl says otherwise --
    # when rabbitmqctl status says rabbit is running, it is probably correct,
    # but when it says it is not we cannot really be sure.
    status_command "rabbitmqctl status || ps aux |grep -q '^rabbitmq.*/var/lib/rabbitmq'"
  end
  action [:enable, :start]
end

bash "Enable rabbit management" do
  code <<-'EOH'
/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
exit 0
EOH
  not_if "su - rabbitmq -s /bin/bash -c \"/usr/lib/rabbitmq/bin/rabbitmq-plugins list -E\" | grep -q rabbitmq_management"
  notifies :restart, "service[rabbitmq-server]", :immediately
end unless node.platform == "suse"
