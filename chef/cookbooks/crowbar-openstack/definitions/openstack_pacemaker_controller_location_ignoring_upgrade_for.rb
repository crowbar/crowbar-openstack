#
# Copyright 2016, SUSE
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

define :openstack_pacemaker_controller_location_ignoring_upgrade_for do
  resource = params[:name]
  location_name = "l-#{resource}-controller"
  pacemaker_location location_name do
    definition OpenStackHAHelper.controller_only_location_ignoring_upgrade(location_name, resource)
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  location_name
end
