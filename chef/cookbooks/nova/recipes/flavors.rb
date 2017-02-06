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

nova_insecure = node[:nova][:ssl][:insecure]
ssl_insecure = keystone_settings["insecure"] || nova_insecure

novacmd = "nova --os-username #{keystone_settings["service_user"]} " \
"--os-password #{keystone_settings["service_password"]} " \
"--os-tenant-name #{keystone_settings["service_tenant"]} " \
"--os-auth-url #{keystone_settings["internal_auth_url"]} " \
"--os-region-name '#{keystone_settings["endpoint_region"]}'"

if ssl_insecure
  novacmd = "#{novacmd} --insecure"
end
if keystone_settings["api_version"] != "2.0"
  novacmd = "#{novacmd} --os-user-domain-name Default --os-project-domain-name Default"
end

trusted_flavors = flavors.select{ |key, value| value["name"].match(/\.trusted\./) }
default_flavors = flavors.select{ |key, value| !value["name"].match(/\.trusted\./) }

# create the trusted flavors
if node[:nova][:trusted_flavors]
  trusted_flavors.keys.each do |id|
    execute "register_#{flavors[id]["name"]}_flavor" do
      command <<-EOF
  #{novacmd} flavor-create #{flavors[id]["name"]} #{id} #{flavors[id]["mem"]} \
  #{flavors[id]["disk"]} #{flavors[id]["vcpu"]}
  #{novacmd} flavor-key #{flavors[id]["name"]} set trust:trusted_host=trusted
  EOF
      not_if lazy { system("#{novacmd} flavor-show #{flavors[id]["name"]}", out: File::NULL) }
      action :nothing
      subscribes :run, "execute[trigger-flavor-creation]", :delayed
    end
  end
end

# create the default flavors
if node[:nova][:create_default_flavors]
  default_flavors.keys.each do |id|
    execute "register_#{flavors[id]["name"]}_flavor" do
      command <<-EOF
  #{novacmd} flavor-create #{flavors[id]["name"]} #{id} #{flavors[id]["mem"]} \
  #{flavors[id]["disk"]} #{flavors[id]["vcpu"]}
  EOF
      not_if lazy { system("#{novacmd} flavor-show #{flavors[id]["name"]}", out: File::NULL) }
      action :nothing
      subscribes :run, "execute[trigger-flavor-creation]", :delayed
    end
  end
end

# This is to trigger all the above "execute" resources to run :delayed, so that
# they run at the end of the chef-client run, after the nova service has been
# restarted (in case of a config change)
execute "trigger-flavor-creation" do
  command "true"
end
