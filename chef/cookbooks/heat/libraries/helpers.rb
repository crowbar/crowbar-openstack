#
# Copyright 2017 SUSE Linux GmbH
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

module HeatHelper
  def self.get_bind_host_port(node)
    if node[:heat][:ha][:enabled]
      admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
      bind_host = admin_address
      api_port = node[:heat][:ha][:ports][:api_port]
      cfn_port = node[:heat][:ha][:ports][:cfn_port]
    else
      bind_host = "0.0.0.0"
      api_port = node[:heat][:api][:port]
      cfn_port = node[:heat][:api][:cfn_port]
    end
    [bind_host, api_port, cfn_port]
  end
end
