# Copyright 2019 SUSE Linux GmbH.
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

if node[@cookbook_name][:api][:protocol] == "https"
  ssl_setup "setting up ssl for octavia" do
    generate_certs node[@cookbook_name][:ssl][:generate_certs]
    certfile node[@cookbook_name][:ssl][:certfile]
    keyfile node[@cookbook_name][:ssl][:keyfile]
    group node[@cookbook_name][:group]
    fqdn node[:fqdn]
    cert_required node[@cookbook_name][:ssl][:cert_required]
    ca_certs node[@cookbook_name][:ssl][:ca_certs]
  end
end
