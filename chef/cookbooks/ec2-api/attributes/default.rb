# Copyright 2016 SUSE Linux GmbH, Inc.
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

# NOTE: keep it under the nova namespace as long as ec2-api does not
# have its own barclamp
default[:nova]["ec2-api"][:db][:database] = "ec2"
default[:nova]["ec2-api"][:db][:user] = "ec2"
default[:nova]["ec2-api"][:db][:password] = nil # must be set by wrapper
default[:nova]["ec2-api"][:user] = "ec2-api"
default[:nova]["ec2-api"][:group] = "ec2-api"
default[:nova]["ec2-api"][:ha][:enabled] = false

default[:nova]["ec2-api"][:config_file] = "/etc/ec2api/ec2api.conf.d/100-ec2api.conf"

default[:nova]["ec2-api"][:ssl][:enabled] = false
default[:nova]["ec2-api"][:ssl][:certfile] = "/etc/ec2api/ssl/certs/signing_cert.pem"
default[:nova]["ec2-api"][:ssl][:keyfile] = "/etc/ec2api/ssl/private/signing_key.pem"
default[:nova]["ec2-api"][:ssl][:generate_certs] = false
default[:nova]["ec2-api"][:ssl][:insecure] = false
default[:nova]["ec2-api"][:ssl][:cert_required] = false
default[:nova]["ec2-api"][:ssl][:ca_certs] = "/etc/ec2api/ssl/certs/ca.pem"
