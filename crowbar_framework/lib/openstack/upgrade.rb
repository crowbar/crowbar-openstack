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
      # keystone is not included here because we keep it running for some longer
      # during the upgrade and don't what the chef-recipes to trigger the database
      # schema migrations.

      # we can't search by roles (like 'neutron-server') because at
      # this point the nodes maybe don't have roles assigned anymore
      components = [
        :ceilometer, :cinder, :glance, :heat,
        :manila, :neutron, :nova, :monasca
      ]
      NodeObject.all.each do |node|
        save_it = false

        complete_components = components.clone
        # run keystone db_sync only in non-ha scenarios
        complete_components << "keystone" if node["keystone"] && !node["keystone"]["ha"]["enabled"]
        complete_components.each do |component|
          [:db_synced, :api_db_synced, :db_monapi_synced].each do |flag|
            if node[component] && node[component][flag]
              node[component][flag] = false
              save_it = true
            end
          end
        end
        node.save if save_it
      end
    end

    class << self
      def enable_repos_for_feature(feature, logger)
        Crowbar::Repository.check_all_repos.each do |repo|
          next unless (repo.config["features"] || []).include? feature

          # enable disabled repos now
          logger.info("enabling repository #{repo.id}")
          provisioner_service = ProvisionerService.new(logger)
          provisioner_service.enable_repository(repo.platform, repo.arch, repo.id)
        end
      end

      def check_ha_repo(logger)
        return nil unless Proposal.where(barclamp: "pacemaker")
        return false unless Crowbar::Repository.provided?("ha")

        unless Crowbar::Repository.provided_and_enabled?("ha")
          enable_repos_for_feature("ha", logger)
        end

        true
      end

      def check_ceph_repo(logger)
        return nil unless Proposal.where(barclamp: "ceph")
        return false unless Crowbar::Repository.provided?("ceph")

        unless Crowbar::Repository.provided_and_enabled?("ceph")
          enable_repos_for_feature("ceph", logger)
        end

        true
      end
    end
  end
end
