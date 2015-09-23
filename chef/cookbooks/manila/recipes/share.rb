#
# Copyright 2015 SUSE Linux GmbH
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
# Cookbook Name:: manila
# Recipe:: share
#

include_recipe "#{@cookbook_name}::common"

# loop over all shares
node[:manila][:shares].each_with_index do |share, share_idx|
  # backend_id = "backend-#{share['backend_driver']}-#{share_idx}"

  Chef::Log.debug("#{share_idx} -> #{share}")
  case
  when share[:backend_driver] == "generic"
    # nothing special needs to be done for the generic driver
  when share[:backend_driver] == "netapp"
    # FIXME (toabctl): Do some NetApp config magic.
  when share[:backend_driver] == "manual"
    # nothing special needs to be done for the generic driver
  end
end

manila_service("share")
