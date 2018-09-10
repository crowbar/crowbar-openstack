#
# Copyright 2015, SUSE
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

# These helper methods provides a convenient way to create Pacemaker
# location constraints which limit resources to only run on OpenStack
# controller nodes or compute nodes.
#
# Example usage:
#
#   service_name = "keystone"
#   location_name = "l-#{service_name}-controller"
#   pacemaker_location location_name do
#     definition OpenStackHAHelper.controller_only_location(location_name, service_name)
#     action :update
#     only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
#   end
#   transaction_objects << "pacemaker_location[#{location_name}]"

module OpenStackHAHelper
  def self.controller_only_location(location, service)
    "location #{location} #{service} resource-discovery=exclusive " \
      "rule 0: OpenStack-role eq controller and pre-upgrade ne true"
  end

  def self.controller_only_location_ignoring_upgrade(location, service)
    "location #{location} #{service} resource-discovery=exclusive " \
      "rule 0: OpenStack-role eq controller"
  end

  def self.drbd_controller_only_location(location, service)
    "location #{location} #{service} resource-discovery=exclusive " \
      "rule 0: OpenStack-role eq controller and drbd-controller eq true"
  end

  def self.no_compute_location(location, service)
    "location #{location} #{service} resource-discovery=exclusive " \
      "rule 0: OpenStack-role ne compute"
  end

  def self.compute_only_location(location, service)
    "location #{location} #{service} resource-discovery=exclusive " \
      "rule 0: OpenStack-role eq compute"
  end
end
