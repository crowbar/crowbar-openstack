# Copyright 2016, SUSE
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

case node[:platform_family]
when "rhel", "suse"
  default[:ironic][:platform] = {
    packages: [
      "openstack-ironic",
      "openstack-ironic-api",
      "openstack-ironic-conductor",
      "python-ironicclient",
      "python-openstackclient",
      "qemu-tools"
    ],
    services: [
      "openstack-ironic-api",
      "openstack-ironic-conductor"
    ],
    driver_dependencies: {
    }
  }
  default[:ironic][:api][:service_name] = "openstack-ironic-api"
  default[:ironic][:conductor][:service_name] = "openstack-ironic-conductor"

when "debian"
  default[:ironic][:platform] = {
    packages: [
      "ironic-api",
      "ironic-conductor",
      "python-ironicclient",
      "python-openstackclient",
      "qemu-utils"
    ],
    services: [
      "ironic-api",
      "ironic-api-conductor"
    ],
    driver_dependencies: {
    }
  }
  default[:ironic][:api][:service_name] = "ironic-api"
  default[:ironic][:conductor][:service_name] = "ironic-conductor"
end

default[:ironic][:debug] = false
default[:ironic][:max_header_line] = 16384

default[:ironic][:user] = "ironic"
default[:ironic][:group] = "ironic"

default[:ironic][:db][:database] = "ironic"
default[:ironic][:db][:user] = "ironic"
default[:ironic][:db][:password] = "" # Set by Crowbar

default[:ironic][:service_user] = "ironic"
default[:ironic][:service_password] = "" # Set by Crowbar

default[:ironic][:api][:protocol] = "http"
default[:ironic][:api][:port] = 6385

default[:ironic][:config_file] = "/etc/ironic/ironic.conf.d/100-ironic.conf"

default[:ironic][:tftproot] = "/var/lib/ironic/tftpboot"

default[:ironic][:pxe_append_params] = "nofb nomodeset vga=normal"

default[:ironic][:enabled_drivers] = []

default[:ironic][:configdrive_use_object_store] = true
