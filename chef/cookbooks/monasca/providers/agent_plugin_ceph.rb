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
  # initialize the data structure if not available
  node[:monasca] ||= {}
  node[:monasca][:agent_plugin_config] ||= {}
  node[:monasca][:agent_plugin_config][:ceph_instances] ||= {}

  # add the hash with the given values
  node[:monasca][:agent_plugin_config][:ceph_instances][new_resource.built_by] =
    { "built_by" => new_resource.built_by,
      "cluster_name" => new_resource.cluster_name,
      "use_sudo" => new_resource.use_sudo }

  ceph_instances = node[:monasca][:agent_plugin_config][:ceph_instances]

  # be sure the package is installed. that way "/etc/monasca/agent/conf.d/" is available
  # and also the user and group are there
  package "openstack-monasca-agent"

  # NOTE(toabctl): convert/parse first to/from json. Otherwise we have unwanted markers
  # like "- !ruby/hash:Mash" in the yaml output
  ceph_conf = JSON.parse({ "init_config" => nil,
                           "instances" => ceph_instances.values }.to_json).to_yaml

  # write http_check plugin config
  file "/etc/monasca/agent/conf.d/ceph.yaml" do
    content ceph_conf
    owner node[:monasca][:agent][:user]
    group node[:monasca][:agent][:group]
    mode "0640"
    notifies :restart, resources(service: node[:monasca][:agent][:agent_service_name]), :delayed
  end
end
