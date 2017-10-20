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

define :openstack_pacemaker_primitive,
    agent: nil,
    params: {},
    op: {},
    action: [] do
  primitive_name = params[:name]
  agent = params[:agent]
  op = params[:op]
  action = params[:action]

  fake_params = {}

  unless op["monitor"].nil? || op["monitor"]["on-fail"].nil?
    op_defaults = CrowbarPacemakerHelper.op_defaults(node)
    op["monitor"] = op["monitor"].merge("on-fail" => op_defaults["monitor"]["on-fail"])
  end

  pacemaker_primitive primitive_name do
    agent agent
    params fake_params
    op op
    action action
  end

end
