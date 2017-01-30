# Copyright 2017 SUSE Linux GmbH
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

package "openstack-trove"

# crowbar 3.0 had a customized api-paste.ini .
# Since crowbar 4.0 (OpenStack >= Mitaka) it's the api-paste from upstream
# TODO(itxaka): This is probably not needed anymore and we can use the one from the package
template "/etc/trove/api-paste.ini" do
  source "api-paste.ini.erb"
  owner "root"
  group node[:trove][:group]
  mode "0640"
  notifies :restart, "service[trove-api]"
end
