# Copyright 2014 SUSE
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

if node[:ceilometer][:ha][:central][:enabled]

  service_name = "ceilometer-agent-central-service"

  # Allow one retry, to avoid races where two nodes create the primitive at the
  # same time when it wasn't created yet (only one can obviously succeed)
  pacemaker_primitive service_name do
    agent node[:ceilometer][:ha][:central][:agent]
    op node[:ceilometer][:ha][:central][:op]
    # use these params with ocf:openstack:ceilometer-agent-central:
    #params ({
    #  "user"    => node[:ceilometer][:user],
    #  "binary"  => "/usr/bin/ceilometer-agent-central",
    #  "use_service"    => true,
    #  "service" => node[:ceilometer][:agent_central][:service_name]
    #})
    action [ :create, :start ]
    retries 1
    retry_delay 5
  end
end
