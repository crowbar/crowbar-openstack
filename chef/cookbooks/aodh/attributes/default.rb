# Copyright 2016 SUSE, Inc.
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

api_service_name = "aodh-api"
evaluator_service_name = "aodh-evaluator"
listener_service_name = "aodh-listener"
notifier_service_name = "aodh-notifier"

case node[:platform_family]
when "debian"
  default[:aodh][:platform] = {
    packages: [
      "aodh-api",
      "aodh-evaluator",
      "aodh-expirer",
      "aodh-listener",
      "aodh-notifier",
      "python-ceilometerclient"
    ],
    services: ["evaluator", "notifier", "listener"]
  }
when "rhel", "suse"
  default[:aodh][:platform] = {
    packages: [
      "openstack-aodh",
      "openstack-aodh-api",
      "openstack-aodh-evaluator",
      "openstack-aodh-expirer",
      "openstack-aodh-listener",
      "openstack-aodh-notifier",
      "python-aodhclient"
    ],
    services: ["evaluator", "notifier", "listener"]
  }
  api_service_name = "openstack-aodh-api"
  evaluator_service_name = "openstack-aodh-evaluator"
  listener_service_name = "openstack-aodh-listener"
  notifier_service_name = "openstack-aodh-notifier"
end

default[:aodh][:api][:service_name] = api_service_name
default[:aodh][:evaluator][:service_name] = evaluator_service_name
default[:aodh][:notifier][:service_name]  = notifier_service_name
default[:aodh][:listener][:service_name]  = listener_service_name
default[:aodh][:evaluation_interval] = 600
default[:aodh][:alarm_history_ttl] = -1

default[:aodh][:debug] = false

default[:aodh][:user] = "aodh"
default[:aodh][:group] = "aodh"
default[:aodh][:config_file] = "/etc/aodh/aodh.conf.d/100-aodh.conf"

default[:aodh][:service_user] = "aodh"
default[:aodh][:service_password] = ""

default[:aodh][:ssl][:certfile] = "/etc/aodh/ssl/certs/signing_cert.pem"
default[:aodh][:ssl][:keyfile] = "/etc/aodh/ssl/private/signing_key.pem"
default[:aodh][:ssl][:generate_certs] = false
default[:aodh][:ssl][:insecure] = false
default[:aodh][:ssl][:cert_required] = false
default[:aodh][:ssl][:ca_certs] = "/etc/aodh/ssl/certs/ca.pem"

default[:aodh][:api][:protocol] = "http"
default[:aodh][:api][:host] = "0.0.0.0"
default[:aodh][:api][:port] = 8042

# Ports to bind to when haproxy is used for the real ports
default[:aodh][:ha][:ports][:api] = 5562

default[:aodh][:db][:database] = "aodh"
default[:aodh][:db][:user] = "aodh"
default[:aodh][:db][:password] = ""

default[:aodh][:ha][:server][:enabled] = false
default[:aodh][:ha][:evaluator][:agent] = "systemd:#{evaluator_service_name}"
default[:aodh][:ha][:evaluator][:op][:monitor][:interval] = "10s"
default[:aodh][:ha][:notifier][:agent] = "systemd:#{notifier_service_name}"
default[:aodh][:ha][:notifier][:op][:monitor][:interval] = "10s"
default[:aodh][:ha][:listener][:agent] = "systemd:#{listener_service_name}"
default[:aodh][:ha][:listener][:op][:monitor][:interval] = "10s"
