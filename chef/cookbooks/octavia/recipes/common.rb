# Copyright 2019, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

group "octavia" do
  group_name node[:octavia][:group]
  system true
end

user "octavia" do
  shell "/bin/bash"
  comment "Octavia user Server"
  gid node[:octavia][:group]
  system true
  supports manage_home: false
end

directory node[:octavia][:octavia_log_dir] do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end

directory node[:octavia][:octavia_config_dir] do
  owner node[:octavia][:user]
  group node[:octavia][:group]
  recursive true
end

package "python-octaviaclient"
