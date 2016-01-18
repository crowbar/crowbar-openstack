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
  class Upgrade
    # pre-upgrade actions needed for the nodes
    def self.pre_upgrade
    end

    # post-upgrade actions needed for the nodes
    def self.post_upgrade
      unset_db_synced
    end

    # set to false the flag `db_synced` for every OpenStack component,
    # so the next time that Chef runs, will synchronize and update the
    # OpenStack service database
    def self.unset_db_synced
      # we can't search by roles (like 'keystone-server') because at
      # this point the nodes maybe don't have roles assigned anymore
      components = [
        :ceilometer, :cinder, :glance, :heat,
        :keystone, :manila, :neutron, :nova
      ]
      NodeObject.all.each do |node|
        save_it = false
        components.each do |component|
          next unless node[component][:db_synced]
          node[component][:db_synced] = false
          save_it = true
        end
        node.save if save_it
      end
    end
  end
end
