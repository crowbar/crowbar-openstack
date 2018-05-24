# Copyright 2018 SUSE
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
# Sets yarb to auto run after a rabbit cluster failure in order to auto level the
# rabbit queues
#

clustermon_op = { "monitor" => [{ "interval" => "10s" }] }
clustermon_params = { "extra_options" => "-E /usr/bin/yarb-alert-pacemaker.sh --watch-fencing" }
name = "autoyarb"
primitive_running = "crm resource show #{name}"
group_running = "crm resource show g-#{name}"

if node[:rabbitmq][:yarb][:enabled]

  package "python-yarb"

  template "#{ENV["HOME"]}/.yarb.conf" do
    source "yarb.conf.erb"
    owner "root"
    group "root"
    mode "0700"
    variables(
      username: node[:rabbitmq][:user],
      password: node[:rabbitmq][:password],
      vhost: node[:rabbitmq][:vhost],
      hostname: node[:rabbitmq][:management_address],
      port: node[:rabbitmq][:management_port],
      log_level: node[:rabbitmq][:yarb][:log_level],
      threads: node[:rabbitmq][:yarb][:threads],
      wait_time: node[:rabbitmq][:yarb][:wait_time]
    )
  end

  template "/usr/bin/yarb-alert-pacemaker.sh" do
    source "yarb-alert-pacemaker.sh.erb"
    owner "root"
    group "root"
    mode "0755"
  end

  pacemaker_primitive name do
    agent "ocf:pacemaker:ClusterMon"
    op clustermon_op
    params clustermon_params
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_group "g-#{name}" do
    members [name]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_location "l-#{name}" do
    definition OpenStackHAHelper.controller_only_location("l-#{name}", "g-#{name}")
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_transaction name do
    cib_objects [
      "pacemaker_primitive[#{name}]",
      "pacemaker_group[g-#{name}]",
      "pacemaker_location[l-#{name}]"
    ]
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
else

  pacemaker_location "l-#{name}" do
    definition OpenStackHAHelper.controller_only_location("l-#{name}", "g-#{name}")
    action :delete
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  pacemaker_group "g-#{name}" do
    members [name]
    action [:stop, :delete]
    only_if do
      running = system(group_running, err: File::NULL)
      CrowbarPacemakerHelper.is_cluster_founder?(node) && running
    end
  end

  pacemaker_primitive name do
    agent "ocf:pacemaker:ClusterMon"
    op clustermon_op
    params clustermon_params
    action [:stop, :delete]
    only_if do
      running = system(primitive_running, err: File::NULL)
      CrowbarPacemakerHelper.is_cluster_founder?(node) && running
    end
  end

  package "python-yarb" do
    action :remove
  end

  file "#{ENV["HOME"]}/.yarb.conf" do
    action :delete
  end

  file "/usr/bin/yarb-alert-pacemaker.sh" do
    action :delete
  end

end
