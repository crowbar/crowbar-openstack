#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
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

module Barclamp
  module CinderHelper
    def volume_driver_for_cinder(selected)
      options_for_select(
        [
          [t(".volumes.raw_volume_driver"), "raw"],
          [t(".volumes.emc_volume_driver"), "emc"],
          [t(".volumes.eqlx_volume_driver"), "eqlx"],
          [t(".volumes.eternus_volume_driver"), "eternus"],
          [t(".volumes.hitachi_volume_driver"), "hitachi"],
          [t(".volumes.netapp_volume_driver"), "netapp"],
          [t(".volumes.nfs_volume_driver"), "nfs"],
          [t(".volumes.pure_volume_driver"), "pure"],
          [t(".volumes.rbd_volume_driver"), "rbd"],
          [t(".volumes.vmware_volume_driver"), "vmware"],
          [t(".volumes.local_volume_driver"), "local"],
          [t(".volumes.manual_volume_driver"), "manual"]
        ],
        selected.to_s
      )
    end

    def raw_methods_for_cinder(selected)
      options_for_select(
        [
          ["First Available", "first"],
          ["All Available", "all"]
        ],
        selected.to_s
      )
    end

    def netapp_storage_family(selected)
      options_for_select(
        [
          ["Clustered Data ONTAP", "ontap_cluster"]
        ],
        selected.to_s
      )
    end

    def netapp_storage_protocol(selected)
      options_for_select(
        [
          ["iSCSI", "iscsi"],
          ["NFS", "nfs"]
        ],
        selected.to_s
      )
    end

    def netapp_transports_for_cinder(selected)
      options_for_select(
        [
          ["HTTP", "http"],
          ["HTTPS", "https"]
        ],
        selected.to_s
      )
    end

    def eternus_protocols_for_cinder(selected)
      options_for_select(
        [
          ["iSCSI", "iscsi"],
          ["FibreChannel", "fc"]
        ],
        selected.to_s
      )
    end

    def api_protocols_for_cinder(selected)
      options_for_select(
        [
          ["HTTP", "http"],
          ["HTTPS", "https"]
        ],
        selected.to_s
      )
    end

    def hitachi_storage_protocol(selected)
      options_for_select(
        [
          ["iSCSI", "iscsi"],
          ["FibreChannel", "fc"]
        ],
        selected.to_s
      )
    end
  end
end
