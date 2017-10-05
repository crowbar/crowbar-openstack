#
# Cookbook Name:: nova
# Recipe:: availability_zones
#
# Copyright 2014, SUSE
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

# non-hyperv nodes set their AZ themselves, so only look for hyperv nodes

elements = node[:nova][:elements_expanded] || node[:nova][:elements]
return if elements["nova-compute-hyperv"].nil? || elements["nova-compute-hyperv"].empty?

command_no_arg = NovaAvailabilityZone.fetch_set_az_command_no_arg(node, @cookbook_name)

hyperv_nodes = node_search_with_cache("roles:nova-compute-hyperv")
hyperv_nodes.each do |n|
  command = NovaAvailabilityZone.add_arg_to_set_az_command(command_no_arg, n)

  execute "Set availability zone for #{n.hostname}" do
    command command
    timeout 15
    returns [0, 68]
    action :nothing
    subscribes :run, "execute[trigger-nova-az-config]", :delayed
  end
end

# This is to trigger all the above "execute" resources to run :delayed, so that
# they run at the end of the chef-client run, after the nova service have been
# restarted (in case of a config change)
execute "trigger-nova-az-config" do
  command "true"
end
