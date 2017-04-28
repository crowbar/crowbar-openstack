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

module SwiftHelper
  def self.get_bind_host_port(node)
    if node[:swift][:ha][:enabled]
      local_ip = Swift::Evaluator.get_ip_by_type(node, :admin_ip_expr)
      bind_host = local_ip
      bind_port = node[:swift][:ha][:ports][:proxy]
    else
      bind_host = "0.0.0.0"
      bind_port = node[:swift][:ports][:proxy]
    end
    return bind_host, bind_port
  end
end
