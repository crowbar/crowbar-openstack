# Copyright 2019, SUSE LLC.
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

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"

cmd = OctaviaHelper.get_openstack_command(node, node[:octavia])

octavia_conf "api" do
  cmd cmd
end

package "openstack-octavia-api" if ["rhel", "suse"].include? node[:platform_family]

include_recipe "#{@cookbook_name}::database"

crowbar_openstack_wsgi "WSGI entry for octavia-api" do
  bind_host OctaviaHelper.bind_host(node, "api")
  bind_port OctaviaHelper.bind_port(node, "api")
  daemon_process "octavia-api"
  script_alias "/usr/bin/octavia-wsgi"
  user node[:octavia][:user]
  group node[:octavia][:group]
  ssl_enable node[:octavia][:api][:protocol] == "https"
  ssl_certfile node[:octavia][:ssl][:certfile]
  ssl_keyfile node[:octavia][:ssl][:keyfile]
  ssl_cacert node[:octavia][:ssl][:ca_certs] if node[:octavia][:ssl][:cert_required]
end

apache_site "octavia-api.conf" do
  enable true
end
