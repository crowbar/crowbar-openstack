#
# Copyright (c) 2016 SUSE Linux GmbH.
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

module ManilaHelper
  def self.has_cephfs_share?(node)
    # check if any share uses cephfs
    node[:manila][:shares].each do |share|
      return true if share["backend_driver"] == "cephfs"
    end
    false
  end

  def self.has_cephfs_internal_cluster?(node)
    # are we using a crowbar-deployed ceph cluster?
    node[:manila][:shares].each do |share|
      next unless share[:backend_driver] == "cephfs"
      return true if share[:cephfs][:use_crowbar]
    end
    false
  end
end
