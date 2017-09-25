#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2008-2009, Opscode, Inc.
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

if node[:database].key?("ec2") && !FileTest.directory?(node[:database][:mysql][:ec2_path])

  service "mysql" do
    action :stop
  end

  execute "install-mysql" do
    command "mv #{node[:database][:mysql][:datadir]} #{node[:database][:mysql][:ec2_path]}"
    not_if { FileTest.directory?(node[:database][:mysql][:ec2_path]) }
  end

  directory node[:database][:mysql][:ec2_path] do
    owner "mysql"
    group "mysql"
  end

  mount node[:database][:mysql][:datadir] do
    device node[:database][:mysql][:ec2_path]
    fstype "none"
    options "bind,rw"
    action :mount
  end

  service "mysql" do
    action :start
  end

end

