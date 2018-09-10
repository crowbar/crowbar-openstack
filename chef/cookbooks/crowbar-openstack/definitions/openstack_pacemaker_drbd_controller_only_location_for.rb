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

define :openstack_pacemaker_drbd_controller_only_location_for do
  # ensure attributes are set
  include_recipe "crowbar-pacemaker::attributes"

  resource = params[:name]
  location_name = "l-#{resource}-controller"

  # Make sure drbd nodes are known so that drbd-controller constraint makes sense
  location_def = if node[:pacemaker][:drbd].fetch("nodes", []).any?
    OpenStackHAHelper.drbd_controller_only_location(location_name, resource)
  else
    OpenStackHAHelper.controller_only_location(location_name, resource)
  end

  pacemaker_location location_name do
    definition location_def
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  location_name
end
