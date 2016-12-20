#
# Cookbook Name:: nova
# Recipe:: memcached
#
# Copyright 2014, SUSE Linux Products GmbH
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

package "memcached"

case node[:platform_family]
  when "rhel"
    package "python-memcached"
  when "suse"
    package "python-python-memcached"
end

if node[:memcached][:listen] != node[:nova][:my_ip]
  node.set[:memcached][:listen] = node[:nova][:my_ip]
  node.save
end

memcached_instance "nova"
