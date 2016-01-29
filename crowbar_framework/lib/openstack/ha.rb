#
# Copyright 2016, SUSE LINUX Products GmbH
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

module Openstack
  class HA
    def self.set_role(nodes, role)
      nodes.each do |nodename|
        save_it = false
        node = NodeObject.find_node_by_name nodename

        node[:pacemaker][:attributes] ||= {}
        if node[:pacemaker][:attributes]["OpenStack-role"] != role
          node[:pacemaker][:attributes]["OpenStack-role"] = role
          save_it = true
        end

        if role == "controller"
          unless node[:pacemaker][:apache2][:for_openstack]
            node[:pacemaker][:apache2][:for_openstack] = true
            save_it = true
          end

          unless node[:pacemaker][:haproxy][:for_openstack]
            node[:pacemaker][:haproxy][:for_openstack] = true
            save_it = true
          end
        end

        node.save if save_it
      end
    end

    def self.set_controller_role(nodes)
      set_role(nodes, "controller")
    end

    def self.set_compute_role(nodes)
      set_role(nodes, "compute")
    end
  end
end
