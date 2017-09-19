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

return unless node["roles"].include?("monasca-agent")

bind_host, bind_port = SwiftHelper.get_bind_host_port(node)
swift_protocol = node[:swift][:ssl][:enabled] ? "https" : "http"

monitor_url = "#{swift_protocol}://#{bind_host}:#{bind_port}/"

monasca_agent_plugin_http_check "http_check for swift-proxy" do
  built_by "swift-proxy"
  name "object-store-api"
  url monitor_url
  dimensions "service" => "object-store-api"
end
