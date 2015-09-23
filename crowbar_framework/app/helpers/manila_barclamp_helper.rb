#
# Copyright 2015, SUSE LINUX GmbH
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

module ManilaBarclampHelper
  def manila_contraints
    {
      "manila-server" => {
        "unique" => false,
        "count" => 1,
        "admin" => false
      }
    }
  end

  def share_driver_for_manila(selected)
    options_for_select(
      [
        [t(".shares.generic_share_driver"), "generic"],
        [t(".shares.netapp_share_driver"), "netapp"],
        [t(".shares.manual_share_driver"), "manual"]
      ],
      selected.to_s
    )
  end

  def netapp_transports_for_manila(selected)
    options_for_select(
      [
        ["HTTP", "http"],
        ["HTTPS", "https"]
      ],
      selected.to_s
    )
  end
end
