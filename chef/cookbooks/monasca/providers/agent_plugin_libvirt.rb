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

require "json"
require "yaml"

action :create do
  config = {
    "username" => new_resource.username,
    "user_domain_name" => new_resource.user_domain_name,
    "password" => new_resource.password,
    "project_name" => new_resource.project_name,
    "project_domain_name" => new_resource.project_domain_name,
    "auth_url" => new_resource.auth_url,
    "region_name" => new_resource.region_name
  }.merge(node[:monasca][:agent][:plugins][:libvirt])

  # be sure the package is installed. that way "/etc/monasca/agent/conf.d/" is available
  # and also the user and group are there
  package "openstack-monasca-agent"

  # NOTE(toabctl): convert/parse first to/from json. Otherwise we have unwanted markers
  # like "- !ruby/hash:Mash" in the yaml output
  process_conf = JSON.parse({ "init_config" => config,
                              "instances" => [] }.to_json).to_yaml

  # write libvirt plugin config
  file "/etc/monasca/agent/conf.d/libvirt.yaml" do
    content process_conf
    owner node[:monasca][:agent][:user]
    group node[:monasca][:agent][:group]
    mode "0640"
    notifies :restart, resources(service: node[:monasca][:agent][:agent_service_name]), :delayed
  end
end
