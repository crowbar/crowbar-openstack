#
# Copyright 2017, SUSE
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

define :openstack_pacemaker_controller_clone_for_transaction,
    agent: nil,
    op: {} do
  primitive_name = params[:name]
  agent = params[:agent]
  op = params[:op]

  raise "No agent specified for #{primitive_name}!" if agent.nil?

  pacemaker_primitive primitive_name do
    agent agent
    op op
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  clone_name = "cl-#{primitive_name}"
  pacemaker_clone clone_name do
    rsc primitive_name
    meta CrowbarPacemakerHelper.clone_meta(node)
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  location_name = openstack_pacemaker_controller_only_location_for clone_name

  [
    "pacemaker_primitive[#{primitive_name}]",
    "pacemaker_clone[#{clone_name}]",
    "pacemaker_location[#{location_name}]"
  ]
end
