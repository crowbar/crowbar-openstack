#
# Cookbook Name:: watcher
# Attributes:: default
#
# Copyright 2019, SUSE Linux Products GmbH
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

default[:watcher][:platform] = {
  packages: [
    "openstack-watcher",
    "openstack-watcher-api",
    "openstack-watcher-applier",
    "openstack-watcher-decision-engine",
    "python-watcherclient"
  ]
}

override[:watcher][:user] = "watcher"
override[:watcher][:group] = "watcher"

default[:watcher][:debug] = "False"

default[:watcher][:db][:password] = "" # set by wrapper
default[:watcher][:db][:user] = "watcher"
default[:watcher][:db][:database] = "watcher"

default[:watcher][:api][:protocol] = "http"
default[:watcher][:api][:bind_port] = "9322"
default[:watcher][:api][:log_file] = "/var/log/watcher/api.log"

default[:watcher][:api][:service_name] = "openstack-watcher-api"
default[:watcher][:applier][:service_name] = "openstack-watcher-applier"
default[:watcher][:decision_engine][:service_name] = "openstack-watcher-decision-engine"
default[:watcher][:api][:config_file] = "/etc/watcher/watcher.conf.d/100_watcher.conf"
# NOTE(gyee): both applier and decision-engine shared the same config file with
# api service
default[:watcher][:applier][:config_file] = "/etc/watcher/watcher.conf"
default[:watcher][:decision_engine][:config_file] = "/etc/watcher/watcher.conf"

default[:watcher][:working_directory] = "/var/lib/watcher"
default[:watcher][:image_cache_datadir] = "/var/lib/watcher/state"

default[:watcher][:sql_idle_timeout] = "3600"

default[:watcher][:ssl][:certfile] = "/etc/watcher/ssl/certs/signing_cert.pem"
default[:watcher][:ssl][:keyfile] = "/etc/watcher/ssl/private/signing_key.pem"
default[:watcher][:ssl][:generate_certs] = false
default[:watcher][:ssl][:insecure] = false
default[:watcher][:ssl][:cert_required] = false
default[:watcher][:ssl][:ca_certs] = "/etc/watcher/ssl/certs/ca.pem"

# HA
default[:watcher][:ha][:enabled] = false
# When HAproxy listens on the API port, make service listen elsewhere
default[:watcher][:ha][:ports][:api] = 5590
# pacemaker definitions
default[:watcher][:ha][:api][:op][:monitor][:interval] = "10s"
default[:watcher][:ha][:api][:agent] = "systemd:#{default[:watcher][:api][:service_name]}"
