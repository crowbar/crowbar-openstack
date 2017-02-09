#
# Cookbook Name:: nova
# Attributes:: default
#
# Copyright 2008-2011, Opscode, Inc.
# Copyright 2011, Dell, Inc.
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

default[:nova][:debug] = false
default[:nova][:max_header_line] = 16384
default[:nova][:config_file] = "/etc/nova/nova.conf.d/100-nova.conf"
default[:nova][:placement_config_file] = "/etc/nova/nova.conf.d/101-nova-placement.conf"

#
# Database Settings
#
default[:nova][:db][:password] = nil
default[:nova][:db][:user] = "nova"
default[:nova][:db][:database] = "nova"

# DB SQLAlchemy parameters
default[:nova][:db][:max_pool_size] = nil
default[:nova][:db][:max_overflow] = nil
default[:nova][:db][:pool_timeout] = nil
default[:nova][:db][:min_pool_size] = nil

#
# Api Database Settings
#
default[:nova][:api_db][:password] = nil
default[:nova][:api_db][:user] = "nova_api"
default[:nova][:api_db][:database] = "nova_api"

# Api DB SQLAlchemy parameters
default[:nova][:api_db][:max_pool_size] = nil
default[:nova][:api_db][:max_overflow] = nil
default[:nova][:api_db][:pool_timeout] = nil

#
# Placement API database settings
#
default[:nova][:placement_db][:password] = nil
default[:nova][:placement_db][:user] = "placement"
default[:nova][:placement_db][:database] = "placement"


# Feature settings
default[:nova][:use_migration] = false
default[:nova][:setup_shared_instance_storage] = false
default[:nova][:use_shared_instance_storage] = false

#
# Hypervisor Settings
#
default[:nova][:libvirt_type] = "kvm"

#
# KVM Settings
#

default[:nova][:kvm][:ksm_enabled] = false

#
# VMware Settings
#

default[:nova][:vcenter][:host] = ""
default[:nova][:vcenter][:port] = 443
default[:nova][:vcenter][:user] = ""
default[:nova][:vcenter][:password] = ""
default[:nova][:vcenter][:clusters] = []
default[:nova][:vcenter][:interface] = ""
default[:nova][:vcenter][:dvs_name] = "dvSwitch0"

#
# Scheduler Settings
#
default[:nova][:scheduler][:ram_allocation_ratio] = 1.0
default[:nova][:scheduler][:cpu_allocation_ratio] = 16.0
default[:nova][:scheduler][:disk_allocation_ratio] = 1.0
default[:nova][:scheduler][:reserved_host_memory_mb] = 512

#
# Placement Settings
#
default[:nova][:placement_service_user] = "placement"
default[:nova][:placement_service_password] = "placement"

#
# Shared Settings
#
default[:nova][:hostname] = "nova"
default[:nova][:user] = "nova"
default[:nova][:group] = "nova"
default[:nova][:home_dir] = "/var/lib/nova"
default[:nova][:instances_path] = "/var/lib/nova/instances"
default[:nova][:vnc_keymap] = "en-us"

default[:nova][:neutron_metadata_proxy_shared_secret] = ""
default[:nova][:neutron_url_timeout] = 30

default[:nova][:service_user] = "nova"
default[:nova][:service_password] = "nova"
default[:nova][:service_ssh_key] = ""

default[:nova][:rbd][:user] = ""
default[:nova][:rbd][:secret_uuid] = ""

default[:nova][:ssl][:enabled] = false
default[:nova][:ssl][:certfile] = "/etc/nova/ssl/certs/signing_cert.pem"
default[:nova][:ssl][:keyfile] = "/etc/nova/ssl/private/signing_key.pem"
default[:nova][:ssl][:generate_certs] = false
default[:nova][:ssl][:insecure] = false
default[:nova][:ssl][:cert_required] = false
default[:nova][:ssl][:ca_certs] = "/etc/nova/ssl/certs/ca.pem"

default[:nova][:novnc][:ssl][:enabled] = false
default[:nova][:novnc][:ssl][:certfile] = ""
default[:nova][:novnc][:ssl][:keyfile] = ""

default[:nova][:ports][:api_ec2] = 8788
default[:nova][:ports][:api] = 8774
default[:nova][:ports][:placement_api] = 8780
default[:nova][:ports][:metadata] = 8775
default[:nova][:ports][:objectstore] = 3333
default[:nova][:ports][:novncproxy] = 6080
default[:nova][:ports][:serialproxy] = 6083

default[:nova][:ha][:enabled] = false
default[:nova][:ha][:op][:monitor][:interval] = "10s"

# EC2 Role Attributes
default[:nova][:ports][:ec2_api] = 8788
default[:nova][:ports][:ec2_metadata] = 8789
default[:nova][:ports][:ec2_s3] = 3334

# EC2 Role HA Ports
default[:nova][:ha][:ports][:ec2_api] = 5557
default[:nova][:ha][:ports][:ec2_metadata] = 5558
default[:nova][:ha][:ports][:ec2_s3] = 5559

# Ports to bind to when haproxy is used for the real ports
default[:nova][:ha][:ports][:api_ec2] = 5550
default[:nova][:ha][:ports][:api] = 5551
default[:nova][:ha][:ports][:metadata] = 5552
default[:nova][:ha][:ports][:objectstore] = 5553
default[:nova][:ha][:ports][:novncproxy] = 5554
default[:nova][:ha][:ports][:serialproxy] = 5556
default[:nova][:ha][:ports][:placement_api] = 5560

default[:nova][:ha][:compute][:enabled] = false
default[:nova][:ha][:compute][:compute][:op][:monitor][:interval] = "10s"
default[:nova][:ha][:compute][:compute][:op][:monitor][:timeout] = "20s"
default[:nova][:ha][:compute][:compute][:op][:start][:timeout] = "600s"
default[:nova][:ha][:compute][:compute][:op][:stop][:timeout] = "300s"
default[:nova][:ha][:compute][:evacuate][:op][:monitor][:interval] = "10s"
default[:nova][:ha][:compute][:evacuate][:op][:monitor][:timeout] = "600s"
default[:nova][:ha][:compute][:evacuate][:op][:start][:timeout] = "20s"
default[:nova][:ha][:compute][:evacuate][:op][:stop][:timeout] = "20s"
default[:nova][:ha][:compute][:fence][:op][:monitor][:interval] = "10m"

#
# Block device settings
#
default[:nova][:block_device][:allocate_retries] = 60
default[:nova][:block_device][:allocate_retries_interval] = 3

#
# Serial device settings
#
default[:nova][:serial][:ssl][:enabled] = false

#
# metadata/vendordata
#
default[:nova][:metadata][:vendordata][:json] = "{}"
