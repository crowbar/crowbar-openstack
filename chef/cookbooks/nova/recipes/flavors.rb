# Copyright 2017 SUSE
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

return unless node[:nova][:create_default_flavors] || node[:nova][:trusted_flavors]
return unless !node[:nova][:ha][:enabled] || CrowbarPacemakerHelper.is_cluster_founder?(node)

# a dict with default and trusted flavors
flavors =
  {
    1 =>
      { "name" => "m1.tiny",
        "vcpu" => 1,
        "disk" => 1,
        "mem" => 512 },
    2 =>
      { "name" => "m1.small",
        "vcpu" => 1,
        "disk" => 20,
        "mem" => 2048 },
    3 =>
      { "name" => "m1.medium",
        "vcpu" => 2,
        "disk" => 40,
        "mem" => 4096 },
    4 =>
      { "name" => "m1.large",
        "vcpu" => 4,
        "disk" => 80,
        "mem" => 8192 },
    5 =>
      { "name" => "m1.xlarge",
        "vcpu" => 8,
        "disk" => 160,
        "mem" => 16384 },
    8 =>
      { "name" => "m1.trusted.tiny",
        "vcpu" => 1,
        "disk" => 0,
        "mem" => 512 },
    9 =>
      { "name" => "m1.trusted.small",
        "vcpu" => 1,
        "disk" => 20,
        "mem" => 2048 },
    10 =>
      { "name" => "m1.trusted.medium",
        "vcpu" => 2,
        "disk" => 40,
        "mem" => 4096 },
    11 =>
      { "name" => "m1.trusted.large",
        "vcpu" => 4,
        "disk" => 80,
        "mem" => 4096 },
    12 =>
      { "name" => "m1.trusted.xlarge",
        "vcpu" => 8,
        "disk" => 80,
        "mem" => 8192 },
  }

keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
nova_config = Barclamp::Config.load("openstack", "nova")
ssl_insecure = CrowbarOpenStackHelper.insecure(nova_config) || keystone_settings["insecure"]

env = "OS_USERNAME='#{keystone_settings["service_user"]}' "
env << "OS_PASSWORD='#{keystone_settings["service_password"]}' "
env << "OS_PROJECT_NAME='#{keystone_settings["service_tenant"]}' "
env << "OS_AUTH_URL='#{keystone_settings["internal_auth_url"]}' "
env << "OS_REGION_NAME='#{keystone_settings["endpoint_region"]}' "
env << "OS_IDENTITY_API_VERSION=#{keystone_settings["api_version"]} "
env << "OS_ENDPOINT_TYPE=internalURL"
novacmd = "#{env} nova"
openstack = "#{env} openstack"

if ssl_insecure
  novacmd = "#{novacmd} --insecure"
  openstack = "#{openstack} --insecure"
end
if keystone_settings["api_version"] != "2.0"
  novacmd = "#{novacmd} --os-user-domain-name Default --os-project-domain-name Default"
  openstack = "#{openstack} --os-user-domain-name Default --os-project-domain-name Default"
end

trusted_flavors = flavors.select{ |key, value| value["name"].match(/\.trusted\./) }
default_flavors = flavors.select{ |key, value| !value["name"].match(/\.trusted\./) }

execute "delay-flavor-creation" do
  command "true"
  action :nothing
end

ruby_block "Get current flavors" do
  block do
    cmd = Mixlib::ShellOut.new("#{openstack} flavor list -f value -c Name").run_command
    raise "Flavor list not obtained, is the nova-api down?" unless cmd.exitstatus.zero?
    node.run_state["flavorlist"] = cmd.stdout.split("\n")
  end
  retries 5
end

ruby_block "Flavor creation" do
  block do
    flavorlist = node.run_state["flavorlist"]

    if node[:nova][:create_default_flavors]
      default_flavors.each do |id, flavor|
        next if flavorlist.include?(flavor["name"])
        command = "#{novacmd} flavor-create #{flavor["name"]} #{id} #{flavor["mem"]} "
        command << "#{flavor["disk"]} #{flavor["vcpu"]}"
        run_context.resource_collection << flavor_create = Chef::Resource::Execute.new(
          "Create flavor #{flavor["name"]}", run_context
        )
        flavor_create.command command
        flavor_create.retries 5

        # delay the run of this resource until the end of the run
        run_context.notifies_delayed(
          Chef::Resource::Notification.new(flavor_create, :run, "delay-flavor-creation")
        )
      end
    end

    if node[:nova][:trusted_flavors]
      trusted_flavors.each do |id, flavor|
        next if flavorlist.include?(flavor["name"])
        command = "#{novacmd} flavor-create #{flavor["name"]} "
        command << "#{id} #{flavor["mem"]} #{flavor["disk"]} #{flavor["vcpu"]} "
        run_context.resource_collection << flavor_create = Chef::Resource::Execute.new(
          "Create trusted flavor #{flavor["name"]}", run_context
        )
        flavor_create.command command
        flavor_create.retries 5

        # delay the run of this resource until the end of the run
        run_context.notifies_delayed(
          Chef::Resource::Notification.new(flavor_create, :run, "delay-flavor-creation")
        )

        # set flavors to trusted
        command = "#{novacmd} flavor-key #{flavor["name"]} set trust:trusted_host=trusted"
        run_context.resource_collection << flavor_trusted = Chef::Resource::Execute.new(
          "Set flavor #{flavor["name"]} to trusted", run_context
        )
        flavor_trusted.command command
        flavor_trusted.retries 5

        # delay the run of this resource until the end of the run
        run_context.notifies_delayed(
          Chef::Resource::Notification.new(flavor_trusted, :run, "delay-flavor-creation")
        )
      end
    end
  end
end
